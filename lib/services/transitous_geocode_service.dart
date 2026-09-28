import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/endpoints/geocode_endpoint.dart';
import '../api/transitous_api_exception.dart';
import '../models/transitous/enums.dart';
import '../models/transitous/match.dart';
import '../utils/geo_utils.dart';

class TransitousGeocodeException implements Exception {
  TransitousGeocodeException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'TransitousGeocodeException: $message';
}

/// A geocoder result as the search UI needs it.
///
/// Thin view over the API's [Match]: the full result is kept in [match] so
/// callers that want the address parts, served modes or matched token ranges
/// can reach them, while the fields below stay as the UI has always used them.
class TransitousLocationSuggestion {
  TransitousLocationSuggestion({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    this.stopId,
    this.country,
    this.defaultArea,
    this.modes = const [],
    this.match,
  });

  /// Identity for display and de-duplication only.
  ///
  /// Every source mints its own — the geocoder falls back to a coordinate when
  /// a match has no id, and favourites, recents, map picks and history all
  /// prefix their own. Never send it to the API; use [stopId].
  final String id;

  /// The feed's id for this stop, e.g. `de-DELFI_de:11000:900100003`.
  ///
  /// Null unless the place is a stop the server named. Only a suggestion with
  /// one can answer a departure board.
  final String? stopId;

  final String name;
  final double lat;
  final double lon;
  final String type;
  final String? country;
  final String? defaultArea;

  /// What serves this stop, as the geocoder or a remembered place said.
  ///
  /// Empty for anywhere that is not a stop, and for stops remembered before
  /// the app recorded it.
  final List<TransitMode> modes;

  /// Null for suggestions built from a raw coordinate.
  final Match? match;

  LatLng get latLng => LatLng(lat, lon);

  /// One decimal is ~10 km: two results with the same name that close are
  /// the same place under two spellings, not two places.
  static const int _dedupeDecimals = 1;

  String get dedupeKey =>
      '${name.toLowerCase()}|'
      '${coordKey(lat, lon, decimals: _dedupeDecimals, separator: '|')}';

  String get subtitle {
    final pieces = <String>[];
    if (defaultArea != null && defaultArea!.isNotEmpty) {
      pieces.add(defaultArea!);
    }
    if (country != null && country!.isNotEmpty) {
      pieces.add(country!);
    }
    return pieces.join(' • ');
  }

  int get typePriority {
    final normalized = type.toLowerCase();
    if (normalized.contains('stop')) return 0;
    if (normalized.contains('place')) return 1;
    if (normalized.contains('address')) return 2;
    return 3;
  }

  factory TransitousLocationSuggestion.fromLatLon(LatLng latLng) {
    return TransitousLocationSuggestion(
      id: _fallbackId(latLng.latitude, latLng.longitude),
      name: coordLabel(latLng.latitude, latLng.longitude, decimals: 6),
      lat: latLng.latitude,
      lon: latLng.longitude,
      type: 'COORDINATE',
    );
  }

  factory TransitousLocationSuggestion.fromMatch(Match match) {
    if (match.name.isEmpty) {
      throw TransitousGeocodeException('Incomplete suggestion payload');
    }
    final type = match.type?.wireName ?? 'STOP';
    return TransitousLocationSuggestion(
      id: match.id.isEmpty ? _fallbackId(match.lat, match.lon) : match.id,
      // Only a named stop gets one: an address or a coordinate has an id the
      // geocoder invented, which /stoptimes rejects.
      stopId: type.toUpperCase() == 'STOP' && match.id.isNotEmpty
          ? match.id
          : null,
      name: match.name,
      lat: match.lat,
      lon: match.lon,
      type: type,
      country: match.country,
      defaultArea: _defaultAreaOf(match),
      modes: match.modes,
      match: match,
    );
  }

  /// The area the geocoder marks as the one to show by default.
  static String? _defaultAreaOf(Match match) {
    for (final area in match.areas) {
      if (area.isDefault) return area.name;
    }
    return null;
  }
}

class TransitousGeocodeService {
  static final RegExp _latLonPattern = RegExp(
    r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  );

  static LatLng? tryParseLatLon(String text) {
    final match = _latLonPattern.firstMatch(text);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lon = double.tryParse(match.group(2)!);
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  }

  static Future<List<TransitousLocationSuggestion>> fetchSuggestions({
    required String text,
    LatLng? placeBias,
    String? type,
  }) async {
    final query = text.trim();
    if (query.length < 3) {
      return const <TransitousLocationSuggestion>[];
    }

    final List<Match> matches;
    try {
      matches = await GeocodeEndpoint.geocode(
        text: query,
        placeLat: placeBias?.latitude,
        placeLon: placeBias?.longitude,
        placeBias: placeBias == null ? null : 5,
        type: type == null ? null : LocationType.fromWire(type),
      );
    } on TransitousApiException catch (e) {
      throw TransitousGeocodeException('Failed to fetch suggestions', e);
    }

    final seen = <String>{};
    final suggestions = <TransitousLocationSuggestion>[];
    final orderMap = <TransitousLocationSuggestion, int>{};
    var order = 0;
    for (final match in matches) {
      try {
        final suggestion = TransitousLocationSuggestion.fromMatch(match);
        final key = suggestion.dedupeKey;
        if (seen.add(key)) {
          suggestions.add(suggestion);
          orderMap[suggestion] = order++;
        }
      } catch (_) {
        continue;
      }
    }
    suggestions.sort((a, b) {
      final byType = a.typePriority.compareTo(b.typePriority);
      if (byType != 0) return byType;
      final ao = orderMap[a] ?? 0;
      final bo = orderMap[b] ?? 0;
      return ao.compareTo(bo);
    });
    return suggestions;
  }

  static Future<TransitousLocationSuggestion?> reverseGeocode({
    required LatLng place,
  }) async {
    final List<Match> matches;
    try {
      matches = await GeocodeEndpoint.reverseGeocode(
        lat: place.latitude,
        lon: place.longitude,
      );
    } on TransitousApiException catch (e) {
      throw TransitousGeocodeException('Failed to reverse geocode', e);
    }

    for (final match in matches) {
      try {
        return TransitousLocationSuggestion.fromMatch(match);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

String _fallbackId(double lat, double lon) =>
    'lat:${lat.toStringAsFixed(6)},lon:${lon.toStringAsFixed(6)}';
