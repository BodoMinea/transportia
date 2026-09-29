import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/endpoints/geocode_endpoint.dart';
import '../api/transitous_api_exception.dart';
import '../models/transitous/enums.dart';
import '../models/transitous/match.dart';
import 'place_bias_service.dart';
import '../utils/geo_utils.dart';
import '../utils/place_bias.dart';
import '../utils/place_caption.dart';

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

  /// Two results with the same name this close are one place listed twice —
  /// a stop in two feeds, say. Further apart, they are two places: the
  /// branches of a chain are often a few hundred metres from each other.
  static const double _samePlaceMetres = 150;

  /// True when [other] is this place again, under the same name.
  bool isSamePlaceAs(TransitousLocationSuggestion other) =>
      name.toLowerCase() == other.name.toLowerCase() &&
      coordinateDistanceInMeters(lat, lon, other.lat, other.lon) <
          _samePlaceMetres;

  /// The line under the name in a result list; see [placeCaption].
  ///
  /// [from] is where the rider is, for the distance; [homeCountry] the
  /// country the phone is set to, which is not spelt out.
  String caption({LatLng? from, String? homeCountry}) => placeCaption(
    name: name,
    district: match?.districtArea?.name,
    city: match?.cityArea?.name ?? defaultArea,
    region: match?.regionArea?.name,
    country: country,
    homeCountry: homeCountry,
    metres: from == null
        ? null
        : coordinateDistanceInMeters(from.latitude, from.longitude, lat, lon),
  );

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

  /// How strongly "Search in this area" holds a search to the map's centre.
  ///
  /// Where results stop moving closer: from 20 up to 100 nothing changes,
  /// and names still match. See docs/geocode-place-bias.md.
  static const double areaPlaceBias = 20;

  /// Results per request. MOTIS answers ten unless asked.
  static const int pageSize = 20;

  /// Results in MOTIS's order, which weighs name, importance and nearness
  /// together; only the same place listed twice is dropped.
  static Future<List<TransitousLocationSuggestion>> fetchSuggestions({
    required String text,
    LatLng? placeBias,
    String? type,
    int numResults = pageSize,
  }) async => (await fetchSuggestionPage(
    text: text,
    placeBias: placeBias,
    type: type,
    numResults: numResults,
  )).suggestions;

  /// [fetchSuggestions], and whether MOTIS answered all [numResults] it was
  /// asked for — when it did, asking for more may find more. Counted before
  /// duplicates are merged, so a page thinned by merging still counts full.
  static Future<({List<TransitousLocationSuggestion> suggestions, bool isFull})>
  fetchSuggestionPage({
    required String text,
    LatLng? placeBias,
    String? type,
    int numResults = pageSize,
    double? biasStrength,
  }) async {
    final query = text.trim();
    if (query.length < 3) {
      return (
        suggestions: const <TransitousLocationSuggestion>[],
        isFull: false,
      );
    }

    // Without an explicit strength, [placeBias] is the rider's own position,
    // sent only as strongly as they allow and not at all once they switched
    // it off. Checked here because every place search passes through. An
    // explicit strength is for a point the rider picked on the map, which
    // says nothing about where they are.
    final strength = biasStrength ?? await PlaceBiasService.load();
    final place = PlaceBias.isOff(strength) ? null : placeBias;

    final List<Match> matches;
    try {
      matches = await GeocodeEndpoint.geocode(
        text: query,
        placeLat: place?.latitude,
        placeLon: place?.longitude,
        placeBias: place == null ? null : strength,
        numResults: numResults,
        type: type == null ? null : LocationType.fromWire(type),
      );
    } on TransitousApiException catch (e) {
      throw TransitousGeocodeException('Failed to fetch suggestions', e);
    }

    final suggestions = <TransitousLocationSuggestion>[];
    for (final match in matches) {
      final TransitousLocationSuggestion suggestion;
      try {
        suggestion = TransitousLocationSuggestion.fromMatch(match);
      } on TransitousGeocodeException {
        continue;
      }
      if (suggestions.any(suggestion.isSamePlaceAs)) continue;
      suggestions.add(suggestion);
    }
    return (suggestions: suggestions, isFull: matches.length >= numResults);
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
