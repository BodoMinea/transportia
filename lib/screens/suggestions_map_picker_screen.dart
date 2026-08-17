import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';
import '../utils/map_marker_utils.dart';
import '../widgets/custom_app_bar.dart';

/// Full-screen map showing every current geocode suggestion as a numbered
/// pin, so the user can pick visually instead of from name/subtitle text
/// alone. Pops with the tapped [TransitousLocationSuggestion], or null if
/// the user backs out without picking one.
class SuggestionsMapPickerScreen extends StatefulWidget {
  const SuggestionsMapPickerScreen({
    super.key,
    required this.suggestions,
    this.title = 'Choose on map',
  });

  final List<TransitousLocationSuggestion> suggestions;
  final String title;

  @override
  State<SuggestionsMapPickerScreen> createState() =>
      _SuggestionsMapPickerScreenState();
}

class _SuggestionsMapPickerScreenState
    extends State<SuggestionsMapPickerScreen> {
  static const String _kMarkerImageId = 'suggestion-map-marker';
  static const LatLng _kFallbackTarget = LatLng(50.087, 14.420);

  MapLibreMapController? _controller;

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
                    onStyleLoadedCallback: _onStyleLoaded,
                    styleString: themeProvider.mapStyleUrl,
                    initialCameraPosition: _initialCamera(),
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ],
            ),
            if (widget.suggestions.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: _buildChipStrip(),
              ),
          ],
        ),
      ),
    );
  }

  CameraPosition _initialCamera() {
    if (widget.suggestions.isEmpty) {
      return const CameraPosition(target: _kFallbackTarget, zoom: 13.0);
    }
    if (widget.suggestions.length == 1) {
      return CameraPosition(
        target: widget.suggestions.first.latLng,
        zoom: 15.0,
      );
    }
    final bounds = _boundsFor(widget.suggestions);
    return CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 12.0,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_handleSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller != null) {
      // Suggestions can sit close together (e.g. several results in the
      // same street) — without this, MapLibre's default collision avoidance
      // can hide pins it thinks would overlap, which otherwise looks
      // identical to them never having been added at all.
      try {
        await controller.setSymbolIconAllowOverlap(true);
        await controller.setSymbolTextAllowOverlap(true);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to configure symbol overlap',
          name: 'SuggestionsMapPickerScreen',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _plotSuggestions();
    if (widget.suggestions.length > 1) {
      unawaited(_fitToSuggestions());
    }
  }

  Future<void> _plotSuggestions() async {
    final controller = _controller;
    if (controller == null || widget.suggestions.isEmpty) return;

    try {
      final image = await buildStopMarkerImage(AppColors.accentOf(context));
      await controller.addImage(_kMarkerImageId, image);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to register suggestion marker image',
        name: 'SuggestionsMapPickerScreen',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    for (int i = 0; i < widget.suggestions.length; i++) {
      try {
        await controller.addSymbol(
          SymbolOptions(
            geometry: widget.suggestions[i].latLng,
            iconImage: _kMarkerImageId,
            // The base dot is small (meant for close-zoom stop markers
            // elsewhere) — scale it up so it reads clearly at the wider
            // zoom levels this picker uses to show several candidates.
            iconSize: 1.8,
            iconAnchor: 'center',
            textField: '${i + 1}',
            textSize: 12,
            textColor: '#FFFFFF',
            textAnchor: 'center',
          ),
          {'index': i},
        );
      } catch (error, stackTrace) {
        developer.log(
          'Failed to add suggestion marker #$i',
          name: 'SuggestionsMapPickerScreen',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _fitToSuggestions() async {
    final controller = _controller;
    if (controller == null) return;
    final bounds = _boundsFor(widget.suggestions);
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 48,
          right: 48,
          bottom: 140,
        ),
      );
    } catch (_) {}
  }

  void _handleSymbolTapped(Symbol symbol) {
    final index = symbol.data?['index'] as int?;
    if (index == null) return;
    _selectSuggestion(index);
  }

  void _selectSuggestion(int index) {
    if (index < 0 || index >= widget.suggestions.length) return;
    unawaited(Haptics.lightTick());
    Navigator.of(context).pop(widget.suggestions[index]);
  }

  Widget _buildChipStrip() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _SuggestionChip(
            index: index,
            suggestion: widget.suggestions[index],
            onTap: () => _selectSuggestion(index),
          );
        },
      ),
    );
  }
}

LatLngBounds _boundsFor(List<TransitousLocationSuggestion> suggestions) {
  double minLat = suggestions.first.lat;
  double maxLat = suggestions.first.lat;
  double minLon = suggestions.first.lon;
  double maxLon = suggestions.first.lon;
  for (final suggestion in suggestions) {
    if (suggestion.lat < minLat) minLat = suggestion.lat;
    if (suggestion.lat > maxLat) maxLat = suggestion.lat;
    if (suggestion.lon < minLon) minLon = suggestion.lon;
    if (suggestion.lon > maxLon) maxLon = suggestion.lon;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLon),
    northeast: LatLng(maxLat, maxLon),
  );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.index,
    required this.suggestion,
    required this.onTap,
  });

  final int index;
  final TransitousLocationSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.solidWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                suggestion.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
