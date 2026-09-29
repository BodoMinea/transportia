import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../api/nominatim_client.dart';
import '../../models/place_details.dart';
import '../../models/stop_time.dart';
import '../../models/transit_mode_group.dart';
import '../../providers/backend_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/favorites_service.dart';
import '../../services/location_service.dart';
import '../../services/stop_times_service.dart';
import '../../services/transitous_geocode_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/geo_utils.dart';
import '../../utils/map_framing.dart';
import '../../utils/map_marker_utils.dart';
import '../../utils/place_caption.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/map/place_details_sheet.dart';
import '../../widgets/validation_toast.dart';
import 'edge_tabs.dart';
import 'result_pins.dart';

/// Points at a place on the map, or picks one of a search's results there.
///
/// Used both to keep a favourite and to answer a location search, because
/// some places are easier to point at than to name. The two say different
/// things about the same gesture, so each is its own constructor.
class MapPlacePickerScreen extends StatefulWidget {
  /// Keeps the place as a favourite, then closes with `true`.
  const MapPlacePickerScreen.favourite({super.key})
    : title = 'Add Favourite',
      confirmLabel = 'Save',
      results = const [],
      origin = null,
      allowsPoint = true,
      _savesFavourite = true;

  /// Hands the place back to the caller as a [TransitousLocationSuggestion],
  /// with the caller naming what it is for: a route's origin is not saved
  /// anywhere, so "Save" would be a false promise.
  ///
  /// With [results], they are pins on the map, framed as the search found
  /// them, and those off screen are pointed at from the edge.
  const MapPlacePickerScreen.pick({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.results = const [],
    this.origin,
    this.allowsPoint = true,
  }) : _savesFavourite = false;

  final String title;

  /// The button that takes the place pointed at.
  final String confirmLabel;

  /// A search's results in its order; empty to only point.
  final List<TransitousLocationSuggestion> results;

  /// Where the rider is, for how far each result is.
  final LatLng? origin;

  /// Whether any point may be picked, or only a result: a timetable needs a
  /// stop, and a point is not one.
  final bool allowsPoint;

  final bool _savesFavourite;

  @override
  State<MapPlacePickerScreen> createState() => _MapPlacePickerScreenState();
}

class _MapPlacePickerScreenState extends State<MapPlacePickerScreen> {
  static const String _kPinsSourceId = 'picker-results-source';
  static const String _kPinsLayerId = 'picker-results-layer';

  /// No closer than this for a city, whose point is only its centre.
  static const double _kSettlementZoom = 12;

  /// No closer than this for a shop, a stop or an address.
  static const double _kPlaceZoom = 16;

  /// Room left around what a frame shows, for the pins drawn at its edges
  /// and the tabs pointing past them.
  static const EdgeInsets _kFramePadding = EdgeInsets.fromLTRB(48, 48, 48, 96);

  /// How much of the map's foot the hint covers, for the tabs to stop above.
  static const double _kHintFootprint = 84;

  /// The sheet may take this share of the map; its facts scroll beyond it.
  static const double _kSheetMaxShare = 0.62;

  /// Departures a stop's sheet lists: the next few, not a timetable.
  static const int _kSheetDepartures = 5;

  static const double _kPinSize = 36;

  static const Duration _kFlyDuration = Duration(milliseconds: 600);

  MapLibreMapController? _controller;
  bool _didInitialCenter = false;
  bool _pinsReady = false;

  /// Where the map looks, as last reported; the tabs are placed from it.
  CameraPosition? _camera;
  Size? _mapSize;

  int? _selectedResult;
  LatLng? _point;
  String? _pointName;
  bool _isLoadingName = false;

  PlaceDetails? _details;
  List<StopTime>? _departures;
  bool _isLoadingExtras = false;

  /// Guards against an earlier, slower lookup filling a later selection.
  int _selectionToken = 0;

  /// The details sheet's height, once laid out: the tabs stop above it,
  /// and a selection is centred in what it leaves.
  double _sheetHeight = 0;

  List<TransitousLocationSuggestion> get _results => widget.results;
  bool get _hasSelection => _selectedResult != null || _point != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: widget.title,
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => _buildMap(context, box.biggest),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, Size size) {
    _mapSize = size;
    final initial = _initialCamera(size);
    final camera = _camera ?? initial;
    return Stack(
      children: [
        MapLibreMap(
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          styleString: context.watch<ThemeProvider>().mapStyleUrl,
          initialCameraPosition: initial,
          myLocationEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          trackCameraPosition: true,
          onCameraMove: (position) => setState(() => _camera = position),
          onMapClick: _onMapTap,
          onMapLongClick: _onMapTap,
        ),
        if (_results.isNotEmpty)
          Positioned.fill(
            child: EdgeTabsLayer(
              view: MapView(
                center: camera.target,
                zoom: camera.zoom,
                size: size,
                bearing: camera.bearing,
              ),
              targets: [for (final r in _results) r.latLng],
              area: Rect.fromLTRB(
                0,
                0,
                size.width,
                size.height - (_hasSelection ? _sheetHeight : _kHintFootprint),
              ),
              taken: _pinRects(camera, size),
              onTap: _showMembers,
            ),
          ),
        if (_hasSelection)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: size.height * _kSheetMaxShare,
              ),
              child: _ReportsHeight(
                onHeight: _onSheetHeight,
                child: _buildSheet(),
              ),
            ),
          )
        else
          Positioned(left: 20, right: 20, bottom: 20, child: _buildHint()),
      ],
    );
  }

  /// Where the results' pins and names are drawn, for the tabs' labels to
  /// keep clear of. Estimated as the map lays them out: the pin centred on
  /// the place, its name below.
  List<Rect> _pinRects(CameraPosition camera, Size size) {
    const nameCharWidth = 7.0;
    const nameHeight = 16.0;
    final view = MapView(
      center: camera.target,
      zoom: camera.zoom,
      size: size,
      bearing: camera.bearing,
    );
    final visible = Offset.zero & size;
    return [
      for (final r in _results)
        if (view.project(r.latLng) case final p when visible.contains(p)) ...[
          Rect.fromCenter(center: p, width: _kPinSize, height: _kPinSize),
          Rect.fromCenter(
            center: p + const Offset(0, _kPinSize / 2 + nameHeight / 2),
            width: nameCharWidth * r.name.length,
            height: nameHeight,
          ),
        ],
    ];
  }

  /// The results framed as the search found them, or the fallback until
  /// the rider's position is known.
  CameraPosition _initialCamera(Size size) {
    final frame = frameResults(
      [for (final r in _results) r.latLng],
      size,
      maxZoom: _closestZoomFor(_results.isEmpty ? null : _results.first),
      padding: _kFramePadding,
    );
    if (frame == null) {
      return const CameraPosition(
        target: LatLng(kFallbackMapLat, kFallbackMapLon),
        zoom: kFallbackMapZoom,
      );
    }
    return CameraPosition(target: frame.center, zoom: frame.zoom);
  }

  double _closestZoomFor(TransitousLocationSuggestion? result) =>
      (result?.match?.isSettlement ?? false) ? _kSettlementZoom : _kPlaceZoom;

  void _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    if (_results.isNotEmpty) return;
    await _centerOnUserIfPossible();
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null || _results.isEmpty) return;
    final accent = AppColors.accentOf(context);
    try {
      for (final icon in {for (final r in _results) resultPinIcon(r)}) {
        await controller.addImage(
          resultPinImageId(icon),
          await buildResultPinImage(accent, icon),
        );
      }
      await controller.addGeoJsonSource(
        _kPinsSourceId,
        resultPinFeatures(_results, selected: _selectedResult),
      );
      await controller.addSymbolLayer(
        _kPinsSourceId,
        _kPinsLayerId,
        SymbolLayerProperties(
          iconImage: [Expressions.get, 'icon'],
          iconSize: [
            Expressions.caseExpression,
            [Expressions.get, 'selected'],
            1.3,
            1.0,
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          symbolSortKey: [Expressions.get, 'sortKey'],
          // Names only where there is room; the pins always show.
          textField: [Expressions.get, 'name'],
          textFont: const ['Noto Sans Bold'],
          textSize: 12,
          textAnchor: 'top',
          textOffset: const [0, 1.4],
          textOptional: true,
          textColor: '#000000',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.5,
        ),
      );
      _pinsReady = true;
    } catch (_) {
      _pinsReady = false;
    }
  }

  Future<void> _refreshPins() async {
    final controller = _controller;
    if (controller == null || !_pinsReady) return;
    try {
      await controller.setGeoJsonSource(
        _kPinsSourceId,
        resultPinFeatures(_results, selected: _selectedResult),
      );
    } catch (_) {}
  }

  /// A pin picks its result; anywhere else, the point itself, where a point
  /// may be picked.
  Future<void> _onMapTap(math.Point<double> point, LatLng coordinates) async {
    final rank = await _resultAt(point);
    if (!mounted) return;
    if (rank != null) {
      _selectResult(rank);
      return;
    }
    if (widget.allowsPoint) {
      _selectPoint(coordinates);
      return;
    }
    _clearSelection();
  }

  Future<int?> _resultAt(math.Point<double> point) async {
    final controller = _controller;
    if (controller == null || !_pinsReady) return null;
    try {
      final features = await controller.queryRenderedFeatures(point, [
        _kPinsLayerId,
      ], null);
      for (final feature in features) {
        final properties = (feature as Map)['properties'];
        if (properties is! Map) continue;
        final rank = properties['rank'];
        if (rank is num) return rank.toInt();
      }
    } catch (_) {}
    return null;
  }

  void _selectResult(int rank) {
    final result = _results[rank];
    final token = ++_selectionToken;
    setState(() {
      _selectedResult = rank;
      _point = null;
      _details = null;
      _departures = null;
      _isLoadingExtras = true;
    });
    unawaited(_refreshPins());
    unawaited(_loadExtras(result, token));
    _centreOnceSheetIsUp(result.latLng);
  }

  void _selectPoint(LatLng coordinates) {
    ++_selectionToken;
    setState(() {
      _selectedResult = null;
      _point = coordinates;
      _pointName = null;
      _isLoadingName = true;
    });
    unawaited(_refreshPins());
    unawaited(_fetchPointName(coordinates));
    _centreOnceSheetIsUp(coordinates);
  }

  void _clearSelection() {
    ++_selectionToken;
    setState(() {
      _selectedResult = null;
      _point = null;
      _sheetHeight = 0;
    });
    unawaited(_refreshPins());
  }

  /// A stop's next departures, or what OpenStreetMap knows of a place.
  Future<void> _loadExtras(
    TransitousLocationSuggestion result,
    int token,
  ) async {
    PlaceDetails? details;
    List<StopTime>? departures;
    final stopId = result.stopId;
    if (stopId != null) {
      try {
        departures = (await StopTimesService.fetchStopTimes(
          stopId: stopId,
          n: _kSheetDepartures,
        )).stopTimes;
      } catch (_) {
        departures = const [];
      }
    } else {
      final backend = BackendProvider.instance;
      final ref = OsmRef.parse(result.match?.id ?? '');
      if (ref != null && (backend?.placeDetailsEnabled ?? true)) {
        details = await NominatimClient.instance.lookup(
          ref,
          host: backend?.nominatimHost ?? NominatimClient.defaultHost,
        );
      }
    }
    if (!mounted || token != _selectionToken) return;
    setState(() {
      _details = details;
      _departures = departures;
      _isLoadingExtras = false;
    });
  }

  void _onSheetHeight(double height) {
    if (!mounted || height == _sheetHeight) return;
    setState(() => _sheetHeight = height);
  }

  /// Pans [p] to the middle of the map the sheet leaves, after the sheet
  /// has been laid out and its height is known.
  void _centreOnceSheetIsUp(LatLng p) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      final camera = _camera ?? _initialCamera(_mapSize ?? Size.zero);
      if (!mounted || controller == null) return;
      final centre = centerPlacing(
        p,
        offset: Offset(0, -_sheetHeight / 2),
        zoom: camera.zoom,
        bearing: camera.bearing,
      );
      unawaited(
        controller.animateCamera(
          CameraUpdate.newLatLng(centre),
          duration: _kFlyDuration,
        ),
      );
    });
  }

  /// Moves the map to show every result a tab stands for: the rider asked
  /// to see them, so none is left to a further tab.
  Future<void> _showMembers(List<int> members) async {
    final controller = _controller;
    final size = _mapSize;
    if (controller == null || size == null || members.isEmpty) return;
    final frame = fitAll(
      [for (final i in members) _results[i].latLng],
      size,
      maxZoom: _closestZoomFor(_results[members.first]),
      padding: _kFramePadding,
    );
    if (frame == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(frame.center, frame.zoom),
      duration: _kFlyDuration,
    );
  }

  Future<void> _fetchPointName(LatLng coordinates) async {
    String? name;
    try {
      final suggestion = await TransitousGeocodeService.reverseGeocode(
        place: coordinates,
      );
      name = suggestion?.name;
    } catch (_) {}
    if (!mounted || _point != coordinates) return;
    setState(() {
      _pointName = name ?? _coordinateName(coordinates);
      _isLoadingName = false;
    });
  }

  static String _coordinateName(LatLng p) =>
      coordLabel(p.latitude, p.longitude);

  Future<void> _centerOnUserIfPossible() async {
    if (_didInitialCenter) return;
    final controller = _controller;
    if (controller == null) return;
    _didInitialCenter = true;

    LatLng? target;
    bool shouldPersist = false;

    try {
      target = await LocationService.loadLastLatLng();
    } catch (_) {}

    bool hasPermission = false;
    try {
      hasPermission = await LocationService.ensurePermission();
    } catch (_) {
      hasPermission = false;
    }

    if (hasPermission) {
      target ??= await _lastKnownLatLng();
      if (target == null) {
        final current = await _currentLatLng();
        if (current != null) {
          target = current;
          shouldPersist = true;
        }
      }
    }

    target ??= const LatLng(kFallbackMapLat, kFallbackMapLon);

    await controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 14.0),
      ),
    );

    if (shouldPersist && mounted) {
      await LocationService.saveLastLatLng(target);
    }
  }

  Future<LatLng?> _lastKnownLatLng() async {
    try {
      final pos = await LocationService.lastKnownPosition();
      if (pos == null) return null;
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _currentLatLng() async {
    try {
      final pos = await LocationService.currentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirm() async {
    final rank = _selectedResult;
    if (rank != null) {
      Navigator.of(context).pop(_results[rank]);
      return;
    }
    final point = _point;
    if (point == null) return;
    final name = _pointName ?? _coordinateName(point);

    if (!widget._savesFavourite) {
      Navigator.of(context).pop(
        TransitousLocationSuggestion(
          id: 'map-${point.latitude}-${point.longitude}',
          name: name,
          lat: point.latitude,
          lon: point.longitude,
          type: 'PLACE',
        ),
      );
      return;
    }

    try {
      await FavoritesService.saveFavorite(
        FavoritePlace(
          id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          lat: point.latitude,
          lon: point.longitude,
          addedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showValidationToast(context, "Failed to add favourite");
      }
    }
  }

  Widget _buildHint() {
    final text = switch ((_results.isNotEmpty, widget.allowsPoint)) {
      (true, true) =>
        'Tap a result for details, or anywhere to pick that point',
      (true, false) => 'Tap a result for details',
      (false, _) => 'Tap anywhere to pick that point',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(text, textAlign: TextAlign.center, style: AppText.bodyMuted),
    );
  }

  Widget _buildSheet() {
    final rank = _selectedResult;
    final homeCountry = View.of(context).platformDispatcher.locale.countryCode;
    if (rank == null) {
      final point = _point!;
      final origin = widget.origin;
      return PlaceDetailsSheet.point(
        title: _pointName ?? _coordinateName(point),
        caption: origin == null
            ? null
            : formatPlaceDistance(
                coordinateDistanceInMeters(
                  origin.latitude,
                  origin.longitude,
                  point.latitude,
                  point.longitude,
                ),
              ),
        isLoading: _isLoadingName,
        confirmLabel: widget.confirmLabel,
        onConfirm: _confirm,
        onCancel: _clearSelection,
      );
    }
    final result = _results[rank];
    final caption = result.caption(
      from: widget.origin,
      homeCountry: homeCountry,
    );
    if (result.stopId != null) {
      return PlaceDetailsSheet.stop(
        icon: resultPinIcon(result),
        title: result.name,
        caption: caption,
        modes: result.modes.isEmpty
            ? null
            : {
                for (final m in result.modes) TransitModeGroup.modeLabel(m),
              }.join(' · '),
        departures: _departures,
        isLoading: _isLoadingExtras,
        confirmLabel: widget.confirmLabel,
        onConfirm: _confirm,
        onCancel: _clearSelection,
      );
    }
    return PlaceDetailsSheet.place(
      icon: resultPinIcon(result),
      title: result.name,
      caption: caption,
      category: categoryLabel(result.match?.category),
      details: _details,
      isLoading: _isLoadingExtras,
      confirmLabel: widget.confirmLabel,
      onConfirm: _confirm,
      onCancel: _clearSelection,
    );
  }
}

/// Tells [onHeight] how tall its child was laid out, after the frame.
class _ReportsHeight extends SingleChildRenderObjectWidget {
  const _ReportsHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportsHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportsHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderReportsHeight extends RenderProxyBox {
  _RenderReportsHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
