import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/favorites_service.dart';
import '../../services/location_service.dart';
import '../../services/transitous_geocode_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/geo_utils.dart';
import '../../utils/map_framing.dart';
import '../../utils/map_marker_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/skeletons/skeleton_shimmer.dart';
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

  /// How much of the map's foot a card covers, for the tabs to stop above:
  /// the hint, or the selection card over it.
  static const double _kHintFootprint = 84;
  static const double _kCardFootprint = 196;

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
                size.height -
                    (_hasSelection ? _kCardFootprint : _kHintFootprint),
              ),
              taken: _pinRects(camera, size),
              onTap: _showMembers,
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: _hasSelection ? _buildSelectionCard() : _buildHint(),
        ),
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
    setState(() {
      _selectedResult = rank;
      _point = null;
    });
    unawaited(_refreshPins());
  }

  void _selectPoint(LatLng coordinates) {
    setState(() {
      _selectedResult = null;
      _point = coordinates;
      _pointName = null;
      _isLoadingName = true;
    });
    unawaited(_refreshPins());
    unawaited(_fetchPointName(coordinates));
  }

  void _clearSelection() {
    setState(() {
      _selectedResult = null;
      _point = null;
    });
    unawaited(_refreshPins());
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
      (true, true) => 'Tap a result, or anywhere to pick that point',
      (true, false) => 'Tap a result to pick it',
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

  Widget _buildSelectionCard() {
    final rank = _selectedResult;
    final result = rank == null ? null : _results[rank];
    final title = result?.name ?? _pointName ?? 'Unknown location';
    final caption = result?.caption(
      from: widget.origin,
      homeCountry: View.of(context).platformDispatcher.locale.countryCode,
    );
    final isLoading = result == null && _isLoadingName;
    final icon = result == null ? LucideIcons.mapPin : resultPinIcon(result);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentOf(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: AppColors.accentOf(context)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result == null ? 'Selected Location' : 'Search result',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    isLoading
                        ? SkeletonShimmer(
                            baseColor: const Color(0xFFE2E7EC),
                            highlightColor: const Color(0xFFF7F9FC),
                            period: const Duration(milliseconds: 1100),
                            child: Container(
                              width: double.infinity,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E7EC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                        : Text(
                            title,
                            style: AppText.heading,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    if (caption != null && caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.black.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _clearSelection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: isLoading ? null : _confirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isLoading
                          ? AppColors.hairline
                          : AppColors.accentOf(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        widget.confirmLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.solidWhite,
                        ),
                      ),
                    ),
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
