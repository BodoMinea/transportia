import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/itinerary.dart';
import '../models/ridden_stretch.dart';
import '../providers/theme_provider.dart';
import '../services/itinerary_navigation_tracker.dart';
import '../services/itinerary_tracking_controller.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../utils/changeover.dart';
import '../utils/color_utils.dart';
import '../utils/duration_formatter.dart';
import '../utils/geo_utils.dart';
import '../utils/haptics.dart';
import '../utils/map_framing.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/itinerary_navigation.dart';
import '../utils/journey_colors.dart' show isStreetLeg;
import '../utils/leg_helper.dart';
import '../utils/map_marker_utils.dart';
import '../utils/polyline_utils.dart';
import '../utils/ridden_line.dart';
import '../utils/reported_time.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/delayed_time.dart';
import '../widgets/gtfs_fields_row.dart';
import '../utils/leg_notices.dart';
import '../widgets/journey/leg_notice_stack.dart';
import '../widgets/stop_departures_sheet.dart';
import '../theme/app_text.dart';

class ItineraryMapScreen extends StatefulWidget {
  final Itinerary itinerary;
  final bool showCarousel;

  /// Which leg to open on, as an index into the *display* legs — the list
  /// `buildDisplayLegs` produces, which drops the edge walks and folds short
  /// mid-journey ones into transfers. Null opens on the whole journey.
  final int? initialLegIndex;

  /// Starts following the journey as soon as the map is up, when the rider is
  /// on or near it. For the button on the itinerary screen, which asks for
  /// tracking and should not leave the rider to find the play button.
  final bool startTracking;

  /// Set when the itinerary is a whole trip being looked at from inside a
  /// journey: the part of its line outside this stretch is drawn light.
  final RiddenStretch? ridden;

  const ItineraryMapScreen({
    super.key,
    required this.itinerary,
    this.showCarousel = true,
    this.initialLegIndex,
    this.startTracking = false,
    this.ridden,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

/// How much of the screen's width one carousel card takes; the rest shows
/// the edges of its neighbours.
const double _kCarouselPageFraction = 0.86;

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  MapLibreMapController? _controller;
  final List<Line> _lines = [];
  final Set<String> _stopMarkerImages = {};
  Color? _stopAccentColor;
  bool _didAddStopsLayer = false;
  Future<void>? _stopsLayerInit;
  bool _isMapReady = false;
  final Map<String, _RouteStop> _stopsById = {};
  _RouteStop? _selectedStopPopup;
  late final PageController _pageController;
  int _currentPage = 0;
  List<List<LatLng>> _legGeometries = [];
  late final List<DisplayLegInfo> _displayLegs;
  late final List<Changeover> _changeovers;

  /// The live tracking session for this journey, when there is one.
  NavigationProgressState? _navTracker;
  bool _canStartNavigation = false;
  int? _lastNavLegIndex;
  late final String _trackingFingerprint;

  /// How near the rider has to be to the route for tracking to be offered.
  static const double _navigationEligibilityThresholdMeters = 250.0;

  /// Clears the app bar, which the tracking controls sit under.
  static const double _navTopBarOffset = 84.0;

  static const double _transferZoomLevel = 16.5;
  static const double _transferDistanceThresholdMeters = 80.0;
  static const String _kStopsSourceId = 'itinerary-stops-source';
  static const String _kStopsLayerId = 'itinerary-stops-layer';
  static const double _lineOpacity = 0.8;

  /// A line the rider is not on, under the one they are.
  static const double _unriddenLineOpacity = 0.3;
  static const double _walkLineWidth = 3.0;
  static const double _nonWalkLineWidth = 3.4;
  static const Color _walkLegColor = Color(0xFF9E9E9E);

  List<DisplayLegInfo> get _mapLegs {
    if (_displayLegs.isNotEmpty) return _displayLegs;
    return List<DisplayLegInfo>.generate(
      widget.itinerary.legs.length,
      (index) => DisplayLegInfo(
        leg: widget.itinerary.legs[index],
        originalIndex: index,
      ),
    );
  }

  List<Leg> _cameraLegs() => _mapLegs.map((entry) => entry.leg).toList();

  @override
  void initState() {
    super.initState();
    _displayLegs = buildDisplayLegs(widget.itinerary.legs);
    _changeovers = changeoversOf(_displayLegs);
    _trackingFingerprint = ItineraryTrackingController.fingerprintFor(
      widget.itinerary,
    );
    // Page 0 is the whole journey, so leg N is page N + 1. _onStyleLoaded
    // already focuses whatever page it opens on.
    final requested = widget.initialLegIndex;
    _currentPage = requested != null && requested >= 0
        ? (requested + 1).clamp(0, _displayLegs.length)
        : 0;

    // Tracking already running for this journey (coming back from the
    // itinerary screen, say) is picked up here, and the carousel opens on the
    // tracked leg. It has to happen before the controller below: a
    // PageController's initial page is only read once.
    final running = ItineraryTrackingController.active.value;
    if (running != null &&
        ItineraryTrackingController.isTracking(_trackingFingerprint)) {
      _navTracker = running;
      _lastNavLegIndex = running.currentLegIndex;
      _currentPage = (running.currentLegIndex + 1).clamp(
        0,
        _displayLegs.length,
      );
      running.addListener(_onNavTrackerChanged);
    }

    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: widget.showCarousel ? _kCarouselPageFraction : 1.0,
    );
    ItineraryTrackingController.active.addListener(_onControllerTrackerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = AppColors.accentOf(context);
    if (_stopAccentColor == color) return;
    _stopAccentColor = color;
    if (_isMapReady) {
      unawaited(_ensureStopMarkerImageForColor(color));
      unawaited(_drawRouteStops());
    }
  }

  @override
  void dispose() {
    _controller?.onFeatureTapped.remove(_handleFeatureTapped);
    ItineraryTrackingController.active.removeListener(
      _onControllerTrackerChanged,
    );
    _navTracker?.removeListener(_onNavTrackerChanged);
    // Tracking belongs to ItineraryTrackingController, not to this screen:
    // closing the map to read the stop list on the itinerary screen does not
    // stop it. Only this screen's own wakelock and listeners go.
    unawaited(WakelockPlus.disable());
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = _navTracker;
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomAppBar(
                  title: 'Journey Map',
                  onBackButtonPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    styleString: context.watch<ThemeProvider>().mapStyleUrl,
                    initialCameraPosition: _calculateInitialCamera(),
                    myLocationEnabled: true,
                    myLocationRenderMode: MyLocationRenderMode.compass,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ],
            ),
            if (widget.showCarousel)
              Positioned(
                left: 16,
                right: 76,
                top: _navTopBarOffset,
                child: _NavigationStatusBanner(
                  gpsSignalLost: tracker?.gpsSignalLost ?? false,
                  arrived: tracker?.arrived ?? false,
                ),
              ),
            if (widget.showCarousel && (_canStartNavigation || tracker != null))
              Positioned(
                top: _navTopBarOffset,
                right: 16,
                child: _NavigationToggleButton(
                  isActive: tracker?.isActive == true,
                  onPressed: tracker?.isActive == true
                      ? _stopNavigation
                      : _startNavigation,
                ),
              ),
            if (widget.showCarousel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: _buildJourneyCarousel(),
              ),
            if (_selectedStopPopup != null)
              Positioned(
                left: 16,
                right: 16,
                top: 76,
                child: _StopInfoPopup(
                  stop: _selectedStopPopup!,
                  onDismiss: () => setState(() => _selectedStopPopup = null),
                  onSeeDepartures: () =>
                      _openStopDeparturesSheet(_selectedStopPopup!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCarousel() {
    if (!widget.showCarousel) {
      return const SizedBox.shrink();
    }

    final totalItems = _displayLegs.length + 1;
    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_shouldShowSwitchTrackingHint) ...[
          _SwitchTrackingHint(onPressed: _switchTrackedLegToDisplayed),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              // A PageView needs a height before it builds its pages, so
              // every card is laid out here once, unseen, at a page's width,
              // and the carousel takes the tallest. A fixed height could not
              // hold a delay line, a warning or larger text in every case.
              SizedBox(width: constraints.maxWidth),
              for (var i = 0; i < totalItems; i++)
                _unseen(
                  SizedBox(
                    width: constraints.maxWidth * _kCarouselPageFraction,
                    child: _buildCarouselItem(i, totalItems),
                  ),
                ),
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: _handlePageChanged,
                  clipBehavior: Clip.none,
                  padEnds: true,
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    return _buildCarouselItem(index, totalItems);
                  },
                ),
              ),
            ],
          ),
        ),
        if (totalItems > 1) ...[
          const SizedBox(height: 12),
          _CarouselIndicator(itemCount: totalItems, activeIndex: _currentPage),
        ],
      ],
    );
  }

  /// Takes up its room and nothing else: not drawn, not tappable, not read
  /// out.
  static Widget _unseen(Widget child) => ExcludeSemantics(
    child: IgnorePointer(
      child: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child,
      ),
    ),
  );

  Widget _buildCarouselItem(int index, int totalItems) {
    final padding = const EdgeInsets.symmetric(horizontal: 12);

    final Widget child;
    if (index == 0) {
      child = _JourneySummaryCard(itinerary: widget.itinerary);
    } else {
      final legIndex = index - 1;
      final entry = _displayLegs[legIndex];
      final leg = entry.leg;
      final accentColor = _getLegColorFromLeg(leg, entry.originalIndex);
      final changeover = entry.isTransfer
          ? _changeovers.where((c) => identical(c.transfer, leg)).firstOrNull
          : null;
      final tracker = _navTracker;
      final progressText =
          (tracker != null &&
              tracker.isActive &&
              tracker.currentLegIndex == legIndex)
          ? progressLabel(
              remainingWalkMeters: tracker.remainingWalkMeters,
              remainingStops: tracker.remainingStops,
            )
          : null;
      child = changeover != null
          ? _TransferCarouselCard(changeover: changeover)
          : _LegCarouselCard(
              leg: leg,
              legIndex: legIndex,
              accentColor: accentColor,
              progressText: progressText,
            );
    }

    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  void _handlePageChanged(int index) {
    if (_currentPage == index) return;
    setState(() => _currentPage = index);
    if (!_isMapReady) return;
    if (index == 0) {
      unawaited(_fitCameraToBounds());
    } else {
      // Not switching the tracked leg along with the page: the rider may
      // only be looking ahead or back. build() offers to switch instead.
      unawaited(_focusLeg(index - 1));
    }
  }

  void _switchTrackedLegToDisplayed() {
    final tracker = _navTracker;
    if (tracker == null || _currentPage <= 0) return;
    tracker.jumpToLeg(_currentPage - 1);
    unawaited(Haptics.mediumTick());
  }

  /// True while tracking is on but the carousel is showing a different leg
  /// from the one being followed.
  bool get _shouldShowSwitchTrackingHint {
    final tracker = _navTracker;
    if (tracker == null || !tracker.isActive || _currentPage <= 0) {
      return false;
    }
    return _currentPage - 1 != tracker.currentLegIndex;
  }

  /// Offers tracking when the rider is on or near the route, and starts it
  /// when it was asked for on the way in.
  Future<void> _evaluateNavigationEligibility() async {
    if (!mounted) return;
    await ItineraryTrackingController.attachIfRunning(_trackingFingerprint);
    if (!mounted || _navTracker != null) return;
    final hasPermission = await LocationService.hasPermission();
    if (!hasPermission || !mounted) return;
    final position = await LocationService.currentOrLastKnownLatLng();
    if (position == null || !mounted || _legGeometries.isEmpty) return;
    final distance = minDistanceToRoute(_legGeometries, position);
    if (distance > _navigationEligibilityThresholdMeters || !mounted) return;
    setState(() => _canStartNavigation = true);
    if (widget.startTracking) unawaited(_startNavigation());
  }

  Future<void> _startNavigation() async {
    if (_navTracker?.isActive == true) return;
    // A fresh fix every time: reusing the one from when the screen opened
    // would keep picking the leg that was nearest then, not where the rider
    // is now.
    final position = await LocationService.currentOrLastKnownLatLng();
    if (position == null || !mounted) return;
    unawaited(Haptics.mediumTick());
    await ItineraryTrackingController.start(
      legs: _displayLegs,
      fingerprint: _trackingFingerprint,
      initialPos: position,
    );
    // _onControllerTrackerChanged is already listening, and animates the
    // carousel to the leg the session starts on.
  }

  void _stopNavigation() {
    ItineraryTrackingController.stopIfMatches(_trackingFingerprint);
  }

  /// Keeps the screen awake only while this screen shows tracking that is
  /// running; a plain journey view, or the app in the background with only
  /// its notification left, sleeps as usual.
  void _syncWakelock() {
    unawaited(WakelockPlus.toggle(enable: _navTracker?.isActive == true));
  }

  /// Fires when the controller's session changes — started, stopped, or moved
  /// from the app to the background service — and not for the ordinary
  /// progress of one, which arrives through [_onNavTrackerChanged].
  void _onControllerTrackerChanged() {
    setState(_syncFromController);
    _syncWakelock();
  }

  void _syncFromController() {
    final session = ItineraryTrackingController.active.value;
    final ours =
        session != null &&
        ItineraryTrackingController.isTracking(_trackingFingerprint);
    final next = ours ? session : null;
    if (identical(next, _navTracker)) return;

    _navTracker?.removeListener(_onNavTrackerChanged);
    _navTracker = next;
    if (next == null) return;

    next.addListener(_onNavTrackerChanged);
    _lastNavLegIndex = next.currentLegIndex;
    _animateToTrackedLeg(next.currentLegIndex);
  }

  void _onNavTrackerChanged() {
    final tracker = _navTracker;
    if (tracker == null || !mounted) return;

    final legIndex = tracker.currentLegIndex;
    if (legIndex != _lastNavLegIndex && legIndex < _displayLegs.length) {
      _lastNavLegIndex = legIndex;
      unawaited(Haptics.mediumTick());
      _animateToTrackedLeg(legIndex);
    }

    setState(() {});
    _syncWakelock();
  }

  void _animateToTrackedLeg(int legIndex) {
    if (!_pageController.hasClients) return;
    unawaited(
      _pageController.animateToPage(
        legIndex + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      ),
    );
  }

  Future<void> _focusLeg(int legIndex) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    if (legIndex < 0 || legIndex >= _legGeometries.length) return;

    final geometry = _legGeometries[legIndex];
    if (geometry.isEmpty) return;

    if (geometry.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(geometry.first, _transferZoomLevel),
      );
      return;
    }

    final isTransfer =
        legIndex < _displayLegs.length && _displayLegs[legIndex].isTransfer;

    final bounds = boundsOf(geometry)!;

    final approxDistance = coordinateDistanceInMeters(
      geometry.first.latitude,
      geometry.first.longitude,
      geometry.last.latitude,
      geometry.last.longitude,
    );
    final shouldClampZoom =
        isTransfer || approxDistance <= _transferDistanceThresholdMeters;
    final center = boundsCenter(bounds);

    if (shouldClampZoom) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(center, _transferZoomLevel),
      );
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 64,
          right: 48,
          bottom: 220,
        ),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(geometry.first, _transferZoomLevel),
      );
    }
  }

  /// Where each leg starts and ends: what the camera frames.
  static List<LatLng> _legEnds(Iterable<Leg> legs) => [
    for (final leg in legs) ...[
      LatLng(leg.fromLat, leg.fromLon),
      LatLng(leg.toLat, leg.toLon),
    ],
  ];

  CameraPosition _calculateInitialCamera() {
    final legs = _cameraLegs();
    if (legs.isEmpty) {
      return const CameraPosition(target: LatLng(50.087, 14.420), zoom: 13.0);
    }

    final center = boundsCenter(boundsOf(_legEnds(legs))!);
    return CameraPosition(target: center, zoom: 13.0);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_handleFeatureTapped);
  }

  void _handleFeatureTapped(
    math.Point<double> point,
    LatLng coordinate,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _kStopsLayerId) return;
    final stop = _stopsById[id];
    if (stop == null) return;
    setState(() => _selectedStopPopup = stop);
  }

  void _openStopDeparturesSheet(_RouteStop stop) {
    final referenceTime = stop.timeAtStop ?? DateTime.now().toUtc();
    setState(() => _selectedStopPopup = null);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Stop departures',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return StopDeparturesSheet(
          stopId: stop.stopId,
          stopName: stop.name?.isNotEmpty == true ? stop.name! : 'Stop',
          referenceTime: referenceTime,
          onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Future<void> _onStyleLoaded() async {
    setState(() => _isMapReady = true);

    await _drawJourneyLegs();
    await _drawRouteStops();
    await _fitCameraToBounds();
    if (_currentPage > 0) {
      await _focusLeg(_currentPage - 1);
    }
    unawaited(_evaluateNavigationEligibility());
  }

  Future<void> _drawJourneyLegs() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) {
      return;
    }

    for (final line in _lines) {
      try {
        await controller.removeLine(line);
      } catch (_) {}
    }
    _lines.clear();
    final displayLegs = _mapLegs;
    if (displayLegs.isEmpty) return;

    final geometries = <List<LatLng>>[];

    for (int i = 0; i < displayLegs.length; i++) {
      final leg = displayLegs[i].leg;
      final color = _getLegColorFromLeg(leg, displayLegs[i].originalIndex);

      List<LatLng> geometry;
      if (leg.legGeometry != null && leg.legGeometry!.points.isNotEmpty) {
        try {
          geometry = decodePolyline(
            leg.legGeometry!.points,
            leg.legGeometry!.precision,
          );
        } catch (e) {
          geometry = [
            LatLng(leg.fromLat, leg.fromLon),
            LatLng(leg.toLat, leg.toLon),
          ];
        }
      } else {
        geometry = [
          LatLng(leg.fromLat, leg.fromLon),
          LatLng(leg.toLat, leg.toLon),
        ];
      }
      final storedGeometry = List<LatLng>.from(geometry);
      geometries.add(storedGeometry);

      // A trip opened from a journey is drawn whole, with the stretch the
      // journey rides on top of the rest, which is light: the rider is not on
      // it. A journey's own legs are only ever the stretch ridden.
      final ridden = riddenPartOfLine(leg, storedGeometry, widget.ridden);
      final lineWidth = leg.mode == 'WALK' ? _walkLineWidth : _nonWalkLineWidth;
      try {
        if (ridden != null) {
          _lines.add(
            await controller.addLine(
              LineOptions(
                geometry: storedGeometry,
                lineColor: colorToHex(color),
                lineWidth: lineWidth,
                lineOpacity: _unriddenLineOpacity,
              ),
            ),
          );
        }
        _lines.add(
          await controller.addLine(
            LineOptions(
              geometry: ridden ?? storedGeometry,
              lineColor: colorToHex(color),
              lineWidth: lineWidth,
              lineOpacity: _lineOpacity,
            ),
          ),
        );
      } catch (e) {}
    }
    _legGeometries = geometries;
  }

  List<_RouteStop> _collectRouteStops() {
    final deduped = <String, _RouteStop>{};
    int order = 0;

    void addStop(
      double lat,
      double lon,
      Color color,
      bool isWalk, {
      bool isTransfer = false,
      String? name,
      String? stopId,
      DateTime? arrival,
      DateTime? departure,
      DateTime? scheduledArrival,
      DateTime? scheduledDeparture,
      bool isLive = false,
    }) {
      final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = _RouteStop(
          point: LatLng(lat, lon),
          color: color,
          order: order++,
          isWalk: isWalk,
          isTransfer: isTransfer,
          name: name,
          stopId: stopId,
          arrival: arrival,
          departure: departure,
          scheduledArrival: scheduledArrival,
          scheduledDeparture: scheduledDeparture,
          arrivalIsLive: isLive,
          departureIsLive: isLive,
        );
        return;
      }
      deduped[key] = _RouteStop(
        point: existing.point,
        color: existing.isWalk && !isWalk ? color : existing.color,
        order: existing.order,
        isWalk: existing.isWalk && isWalk,
        isTransfer: existing.isTransfer || isTransfer,
        name: existing.name ?? name,
        stopId: existing.stopId ?? stopId,
        arrival: existing.arrival ?? arrival,
        departure: existing.departure ?? departure,
        scheduledArrival: existing.scheduledArrival ?? scheduledArrival,
        scheduledDeparture: existing.scheduledDeparture ?? scheduledDeparture,
        // Each flag travels with the time it describes, from whichever leg
        // supplied that time.
        arrivalIsLive: existing.arrival != null
            ? existing.arrivalIsLive
            : isLive,
        departureIsLive: existing.departure != null
            ? existing.departureIsLive
            : isLive,
      );
    }

    for (final entry in _mapLegs) {
      final leg = entry.leg;
      final isWalk = leg.mode == 'WALK';
      final color = _getLegColorFromLeg(leg, entry.originalIndex);
      addStop(
        leg.fromLat,
        leg.fromLon,
        color,
        isWalk,
        isTransfer: entry.isTransfer,
        name: leg.fromName,
        stopId: leg.fromStopId,
        departure: leg.startTime,
        scheduledDeparture: leg.scheduledStartTime,
        isLive: leg.realTime,
      );
      for (final stop in leg.intermediateStops) {
        addStop(
          stop.lat,
          stop.lon,
          color,
          isWalk,
          isTransfer: entry.isTransfer,
          name: stop.name,
          stopId: stop.stopId,
          arrival: stop.arrival,
          departure: stop.departure,
          scheduledArrival: stop.scheduledArrival,
          scheduledDeparture: stop.scheduledDeparture,
          isLive: leg.realTime,
        );
      }
      addStop(
        leg.toLat,
        leg.toLon,
        color,
        isWalk,
        isTransfer: entry.isTransfer,
        name: leg.toName,
        stopId: leg.toStopId,
        arrival: leg.endTime,
        scheduledArrival: leg.scheduledEndTime,
        isLive: leg.realTime,
      );
    }

    final stops = deduped.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return stops;
  }

  Future<void> _drawRouteStops() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    await _ensureStopsLayer();
    if (!_didAddStopsLayer) return;

    final stops = _collectRouteStops();
    _stopsById.clear();
    if (stops.isEmpty) {
      try {
        await controller.setGeoJsonSource(
          _kStopsSourceId,
          _emptyFeatureCollection(),
        );
      } catch (_) {}
      return;
    }

    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final imageId = await _ensureStopMarkerImageForColor(
        stop.color,
        isTransfer: stop.isTransfer,
      );
      if (imageId == null) continue;
      final featureId = i.toString();
      _stopsById[featureId] = stop;
      features.add({
        'type': 'Feature',
        'id': i,
        'properties': {'id': i, 'iconId': imageId, 'order': stop.order},
        'geometry': {
          'type': 'Point',
          'coordinates': [stop.point.longitude, stop.point.latitude],
        },
      });
    }
    try {
      await controller.setGeoJsonSource(_kStopsSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (_) {}
  }

  String _stopMarkerImageIdForColor(Color color, {bool isTransfer = false}) {
    final hex = colorToHex(color).replaceAll('#', '');
    final prefix = isTransfer
        ? 'itinerary-transfer-stop-marker'
        : 'itinerary-stop-marker';
    return '$prefix-$hex';
  }

  Future<String?> _ensureStopMarkerImageForColor(
    Color color, {
    bool isTransfer = false,
  }) async {
    final controller = _controller;
    if (controller == null) return null;
    final imageId = _stopMarkerImageIdForColor(color, isTransfer: isTransfer);
    if (_stopMarkerImages.contains(imageId)) {
      return imageId;
    }
    try {
      final image = await buildStopMarkerImage(color, isTransfer: isTransfer);
      await controller.addImage(imageId, image);
      _stopMarkerImages.add(imageId);
      return imageId;
    } catch (_) {
      return null;
    }
  }

  List<Object> _stopIconSizeExpression() {
    return [
      Expressions.interpolate,
      ['linear'],
      [Expressions.zoom],
      11.0,
      0.55,
      13.0,
      0.7,
      15.0,
      0.85,
      17.0,
      1.0,
    ];
  }

  Map<String, dynamic> _emptyFeatureCollection() {
    return const {'type': 'FeatureCollection', 'features': []};
  }

  Future<void> _ensureStopsLayer() async {
    if (_didAddStopsLayer) return;
    final inFlight = _stopsLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _stopsLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      final color = _stopAccentColor ?? _currentAccentColor();
      final imageId = await _ensureStopMarkerImageForColor(color);
      if (imageId == null) return;
      Set<String> sourceIds;
      Set<String> layerIds;
      try {
        sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
        layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      } catch (_) {
        return;
      }
      final hasSource = sourceIds.contains(_kStopsSourceId);
      final hasLayer = layerIds.contains(_kStopsLayerId);
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kStopsSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (!hasLayer) {
        await controller.addSymbolLayer(
          _kStopsSourceId,
          _kStopsLayerId,
          SymbolLayerProperties(
            iconImage: [Expressions.get, 'iconId'],
            iconSize: _stopIconSizeExpression(),
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: 'center',
            symbolSortKey: [Expressions.get, 'order'],
          ),
          enableInteraction: true,
        );
      }
      _didAddStopsLayer = true;
    } catch (_) {
      _didAddStopsLayer = false;
    } finally {
      _stopsLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Color _getLegColorFromLeg(Leg leg, int _) {
    if (leg.mode == 'WALK') {
      return _walkLegColor;
    }
    final parsed = parseHexColor(leg.routeColor?.trim());
    return parsed ?? _currentAccentColor();
  }

  Color _currentAccentColor() {
    return ThemeProvider.instance?.accentColor ?? AppColors.accent;
  }

  Future<void> _fitCameraToBounds() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;

    await _fitCameraToItinerary(controller);
  }

  Future<void> _fitCameraToItinerary(MapLibreMapController controller) async {
    final legs = _cameraLegs();
    if (legs.isEmpty) return;

    final bounds = boundsOf(_legEnds(legs))!;

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 48,
          right: 48,
          bottom: 220,
        ),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(legs.first.fromLat, legs.first.fromLon)),
      );
    }
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _JourneySummaryCard extends StatelessWidget {
  const _JourneySummaryCard({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final firstLeg = itinerary.legs.isNotEmpty ? itinerary.legs.first : null;
    final lastLeg = itinerary.legs.isNotEmpty ? itinerary.legs.last : null;
    // A walk at either end has no real-time of its own; its times move with
    // the ride next to it, so that ride says whether they are reported.
    final rides = itinerary.legs.where((leg) => !isStreetLeg(leg.mode));
    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Journey overview', style: AppText.bodyStrong),
          const SizedBox(height: 12),
          // Top-aligned: a delay under one of the times makes its column
          // taller, and centring would pull the labels out of line.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _JourneyTimeTile(
                  label: 'Departure',
                  time: ReportedTime.from(
                    firstLeg?.startTime ?? itinerary.startTime,
                    firstLeg?.scheduledStartTime,
                    isLive: rides.firstOrNull?.realTime ?? false,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(LucideIcons.clock, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      formatDuration(itinerary.duration),
                      style: AppText.bodyStrong,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _JourneyTimeTile(
                    label: 'Arrival',
                    time: ReportedTime.from(
                      lastLeg?.endTime ?? itinerary.endTime,
                      lastLeg?.scheduledEndTime,
                      isLive: rides.lastOrNull?.realTime ?? false,
                    ),
                    alignEnd: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopInfoPopup extends StatelessWidget {
  const _StopInfoPopup({
    required this.stop,
    required this.onDismiss,
    required this.onSeeDepartures,
  });

  final _RouteStop stop;
  final VoidCallback onDismiss;
  final VoidCallback onSeeDepartures;

  @override
  Widget build(BuildContext context) {
    final hasArrival = stop.arrival != null || stop.scheduledArrival != null;
    final hasDeparture =
        stop.departure != null || stop.scheduledDeparture != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stop.name?.isNotEmpty == true ? stop.name! : 'Stop',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasArrival || hasDeparture) ...[
                  const SizedBox(height: 6),
                  if (hasArrival)
                    DelayedTime.start(
                      stop.arrivalTime,
                      label: 'Arrival',
                      isArrival: hasDeparture,
                      fontSize: 13,
                    ),
                  if (hasArrival && hasDeparture) const SizedBox(height: 2),
                  if (hasDeparture)
                    DelayedTime.start(
                      stop.departureTime,
                      label: 'Departure',
                      fontSize: 13,
                    ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'No timetable information for this stop.',
                    style: AppText.caption,
                  ),
                ],
                if (stop.stopId != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onSeeDepartures,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all departures',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentOf(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: AppColors.accentOf(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 16,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStop {
  const _RouteStop({
    required this.point,
    required this.color,
    required this.order,
    required this.isWalk,
    required this.isTransfer,
    this.name,
    this.stopId,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.arrivalIsLive = false,
    this.departureIsLive = false,
  });

  final LatLng point;
  final Color color;
  final int order;
  final bool isWalk;
  final bool isTransfer;
  final String? name;
  final String? stopId;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final bool arrivalIsLive;
  final bool departureIsLive;

  ReportedTime? get arrivalTime =>
      ReportedTime.from(arrival, scheduledArrival, isLive: arrivalIsLive);
  ReportedTime? get departureTime =>
      ReportedTime.from(departure, scheduledDeparture, isLive: departureIsLive);

  /// The one time that matters at this stop: when the vehicle leaves, or
  /// when it arrives if it never leaves again.
  DateTime? get timeAtStop => departure ?? arrival;
}

class _LegCarouselCard extends StatelessWidget {
  const _LegCarouselCard({
    required this.leg,
    required this.legIndex,
    required this.accentColor,
    this.progressText,
  });

  final Leg leg;
  final int legIndex;
  final Color accentColor;

  /// How far there is to go, on the leg being tracked and no other.
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    final headline = _resolveHeadline(leg);
    final subtitle = _resolveSubtitle(leg);

    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.subtitle,
          ),
          GtfsFieldsRow(
            fields: {
              'trip': leg.tripId,
              'from stop': leg.fromStopId,
              'to stop': leg.toStopId,
            },
          ),
          const SizedBox(height: 12),
          _LegStopRow(
            icon: LucideIcons.circleDot,
            time: ReportedTime.from(
              leg.startTime,
              leg.scheduledStartTime,
              isLive: leg.realTime,
            ),
            label: leg.fromName,
          ),
          const SizedBox(height: 6),
          _LegStopRow(
            icon: LucideIcons.flag,
            time: ReportedTime.from(
              leg.endTime,
              leg.scheduledEndTime,
              isLive: leg.realTime,
            ),
            label: leg.toName,
          ),
          if (progressText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.navigation, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  progressText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
          LegNoticeStack.headline(legNotices(leg)),
        ],
      ),
    );
  }

  String _resolveHeadline(Leg leg) {
    if (leg.displayName != null && leg.displayName!.isNotEmpty) {
      return leg.displayName!;
    }
    if (leg.routeShortName != null && leg.routeShortName!.isNotEmpty) {
      if (leg.headsign != null && leg.headsign!.isNotEmpty) {
        return '${leg.routeShortName} • ${leg.headsign}';
      }
      return leg.routeShortName!;
    }
    if (leg.routeLongName != null && leg.routeLongName!.isNotEmpty) {
      return leg.routeLongName!;
    }
    if (leg.headsign != null && leg.headsign!.isNotEmpty) {
      return leg.headsign!;
    }
    return getTransitModeName(leg.mode);
  }

  String _resolveSubtitle(Leg leg) {
    final mode = getTransitModeName(leg.mode);
    if (leg.headsign != null && leg.headsign!.isNotEmpty) {
      return '$mode • ${leg.headsign}';
    }
    if (leg.routeLongName != null && leg.routeLongName!.isNotEmpty) {
      return '$mode • ${leg.routeLongName}';
    }
    if (leg.routeShortName != null && leg.routeShortName!.isNotEmpty) {
      return '$mode • ${leg.routeShortName}';
    }
    return mode;
  }
}

class _TransferCarouselCard extends StatelessWidget {
  const _TransferCarouselCard({required this.changeover});

  final Changeover changeover;

  Leg get leg => changeover.transfer;

  @override
  Widget build(BuildContext context) {
    // The walk's own start carries none of the arriving train's real-time,
    // so getting here is read off the place, as the itinerary's spine does.
    // Both times move with that train, so its flag says whether they are
    // reported.
    final isLive = changeover.arriving?.realTime ?? false;
    final arrives = ReportedTime.from(
      changeover.arrivesAt,
      leg.from.scheduledArrival ?? changeover.arriving?.scheduledEndTime,
      isLive: isLive,
    );
    final walked = ReportedTime.from(
      leg.endTime,
      leg.scheduledEndTime,
      isLive: isLive,
    );
    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.arrowLeftRight, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(formatDuration(leg.duration), style: AppText.bodyStrong),
            ],
          ),
          const SizedBox(height: 8),
          _LegStopRow(
            icon: LucideIcons.arrowRight,
            time: arrives,
            label: leg.fromName,
          ),
          if (leg.distance != null && leg.distance! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Approx. ${formatDistanceKm(leg.distance!)} walk',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _LegStopRow(
            icon: LucideIcons.arrowDown,
            time: walked,
            label: leg.toName,
          ),
          LegNoticeStack.headline(
            legNotices(changeover.transfer, changeover: changeover),
          ),
        ],
      ),
    );
  }
}

class _JourneyTimeTile extends StatelessWidget {
  const _JourneyTimeTile({
    required this.label,
    required this.time,
    this.alignEnd = false,
  });

  final String label;
  final ReportedTime? time;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        alignEnd
            ? DelayedTime.end(time, fontSize: 20, fontWeight: FontWeight.w700)
            : DelayedTime.start(
                time,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
      ],
    );
  }
}

class _LegStopRow extends StatelessWidget {
  const _LegStopRow({
    required this.icon,
    required this.time,
    required this.label,
  });

  final IconData icon;
  final ReportedTime? time;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Held to the time's line, so a delay under it pushes the row down
    // rather than drifting the icon and the name off centre.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.black.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        DelayedTime.start(time),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({
    required this.itemCount,
    required this.activeIndex,
  });

  final int itemCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < itemCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: i == activeIndex ? 16 : 6,
                  decoration: BoxDecoration(
                    color: i == activeIndex
                        ? accent
                        : accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Offered while tracking follows one leg and the carousel shows another.
class _SwitchTrackingHint extends StatelessWidget {
  const _SwitchTrackingHint({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.navigation,
                size: 16,
                color: AppColors.solidWhite,
              ),
              const SizedBox(width: 8),
              const Text(
                'Track this leg instead',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.solidWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starts tracking, and stops it again.
class _NavigationToggleButton extends StatelessWidget {
  const _NavigationToggleButton({
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      label: isActive ? 'Stop tracking this trip' : 'Track this trip',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? accent : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: isActive ? 0 : 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isActive ? LucideIcons.square : LucideIcons.play,
            size: 20,
            color: isActive ? AppColors.solidWhite : accent,
          ),
        ),
      ),
    );
  }
}

/// Says when tracking has lost the GPS, or has arrived. Empty otherwise.
class _NavigationStatusBanner extends StatelessWidget {
  const _NavigationStatusBanner({
    required this.gpsSignalLost,
    required this.arrived,
  });

  final bool gpsSignalLost;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    String? message;
    var color = AppColors.solidBlack;
    var icon = LucideIcons.info;

    if (arrived) {
      message = "You've arrived";
      color = const Color(0xFF2E9E5B);
      icon = LucideIcons.circleCheck;
    } else if (gpsSignalLost) {
      message = 'GPS signal lost — position may not update (e.g. underground)';
      color = AppColors.cancelled;
      icon = LucideIcons.satelliteDish;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        );
        return SlideTransition(
          position: animation.drive(offsetTween),
          child: child,
        );
      },
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('nav-banner-empty'))
          : Container(
              key: ValueKey(message),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.solidWhite, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.solidWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
