import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../utils/geo_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/validation_toast.dart';
import '../widgets/skeletons/skeleton_shimmer.dart';
import '../theme/app_text.dart';

/// Points at a place on the map.
///
/// Used both to keep a favourite and to answer a location search, because
/// some places are easier to point at than to name. The two say different
/// things about the same gesture, so each is its own constructor.
class MapPlacePickerScreen extends StatefulWidget {
  /// Keeps the place as a favourite, then closes with `true`.
  const MapPlacePickerScreen.favourite({super.key})
    : title = 'Add Favourite',
      confirmLabel = 'Save',
      _savesFavourite = true;

  /// Hands the place back to the caller, which names what it is for: a
  /// route's origin is not saved anywhere, so "Save" would be a false promise.
  const MapPlacePickerScreen.pick({
    super.key,
    required this.title,
    required this.confirmLabel,
  }) : _savesFavourite = false;

  final String title;

  /// The button that takes the place pointed at.
  final String confirmLabel;

  final bool _savesFavourite;

  @override
  State<MapPlacePickerScreen> createState() => _MapPlacePickerScreenState();
}

class _MapPlacePickerScreenState extends State<MapPlacePickerScreen> {
  LatLng? _selectedLocation;
  String? _selectedLocationName;
  bool _isLoadingName = false;
  MapLibreMapController? _controller;
  bool _didInitialCenter = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomAppBar(
                  title: widget.title,
                  onBackButtonPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    styleString: themeProvider.mapStyleUrl,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(kFallbackMapLat, kFallbackMapLon),
                      zoom: kFallbackMapZoom,
                    ),
                    myLocationEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                    onMapClick: _onMapTap,
                    onMapLongClick: _onMapLongClick,
                  ),
                ),
              ],
            ),
            if (_selectedLocation != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: _buildSelectionCard(),
              ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    await _centerOnUserIfPossible();
  }

  void _onMapTap(math.Point<double> point, LatLng coordinates) {
    _selectLocation(coordinates);
  }

  void _onMapLongClick(math.Point<double> point, LatLng coordinates) {
    _selectLocation(coordinates);
  }

  void _selectLocation(LatLng coordinates) {
    setState(() {
      _selectedLocation = coordinates;
      _selectedLocationName = null;
      _isLoadingName = true;
    });

    _fetchLocationName(coordinates);
  }

  Future<void> _fetchLocationName(LatLng coordinates) async {
    try {
      final suggestion = await TransitousGeocodeService.reverseGeocode(
        place: coordinates,
      );
      if (mounted && _selectedLocation == coordinates) {
        setState(() {
          _selectedLocationName =
              suggestion?.name ??
              '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    } catch (e) {
      if (mounted && _selectedLocation == coordinates) {
        setState(() {
          _selectedLocationName =
              '${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
          _isLoadingName = false;
        });
      }
    }
  }

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
    if (_selectedLocation == null) return;

    final name =
        _selectedLocationName ??
        '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';

    final favorite = FavoritePlace(
      id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      lat: _selectedLocation!.latitude,
      lon: _selectedLocation!.longitude,
      addedAt: DateTime.now(),
    );

    if (!widget._savesFavourite) {
      Navigator.of(context).pop(favorite);
      return;
    }

    try {
      await FavoritesService.saveFavorite(favorite);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showValidationToast(context, "Failed to add favourite");
      }
    }
  }

  Widget _buildSelectionCard() {
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
                child: Icon(
                  LucideIcons.mapPin,
                  size: 24,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingName
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
                            _selectedLocationName ?? 'Unknown location',
                            style: AppText.heading,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                  onTap: () => setState(() => _selectedLocation = null),
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
                  onTap: _isLoadingName ? null : _confirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isLoadingName
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
