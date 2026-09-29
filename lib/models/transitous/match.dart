import 'enums.dart';
import 'json.dart';

/// An administrative area a match sits in, e.g. country, state, city,
/// district.
class Area {
  const Area({
    required this.name,
    required this.adminLevel,
    this.matched = false,
    this.unique = false,
    this.isDefault = false,
  });

  final String name;

  /// OpenStreetMap `admin_level`: lower is broader (2 is a country, 4 a
  /// state, 8 a city).
  final double adminLevel;

  /// True when the search text matched this area rather than the place name.
  final bool matched;

  /// True when this area is what distinguishes an otherwise ambiguous match,
  /// so it is the one worth showing alongside the name.
  final bool unique;

  /// True when this is the area to show by default (closest to admin level 7).
  final bool isDefault;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
    name: asString(json['name']) ?? '',
    adminLevel: asDouble(json['adminLevel']) ?? 0,
    matched: asBool(json['matched']) ?? false,
    unique: asBool(json['unique']) ?? false,
    isDefault: asBool(json['default']) ?? false,
  );
}

/// A range of the query text that a match covers, as `[start, length]`.
///
/// Useful for highlighting the matched part of a suggestion.
class MatchToken {
  const MatchToken({required this.start, required this.length});

  final int start;
  final int length;

  int get end => start + length;

  static MatchToken? fromJson(Object? value) {
    if (value is! List || value.length < 2) return null;
    final start = asInt(value[0]);
    final length = asInt(value[1]);
    if (start == null || length == null) return null;
    return MatchToken(start: start, length: length);
  }
}

/// A geocoder result from `/geocode` or `/reverse-geocode`.
class Match {
  const Match({
    required this.type,
    required this.name,
    required this.id,
    required this.lat,
    required this.lon,
    required this.score,
    this.category,
    this.tokens = const [],
    this.areas = const [],
    this.level,
    this.street,
    this.houseNumber,
    this.country,
    this.zip,
    this.tz,
    this.modes = const [],
    this.importance,
  });

  /// Whether this is a stop, an address or a named place. Null when the
  /// server sends a type this build does not know.
  final LocationType? type;

  final String name;

  /// Feed-prefixed stop id for stops, or an OSM-derived id otherwise.
  ///
  /// For stops this is the value `via`, `/stoptimes` and `/stop` expect.
  final String id;

  final double lat;
  final double lon;

  /// Relevance of this match; higher sorts first.
  final double score;

  /// What kind of place this is, e.g. `supermarket_14`, `fast_food_16`, or
  /// `place_6` for a city. Absent for stops and addresses.
  final String? category;

  /// Which parts of the query text this match covers.
  final List<MatchToken> tokens;

  final List<Area> areas;
  final double? level;
  final String? street;
  final String? houseNumber;
  final String? country;
  final String? zip;
  final String? tz;

  /// Modes served, for stops.
  final List<TransitMode> modes;

  /// Standalone importance of the place, independent of the query.
  final double? importance;

  bool get isStop => type == LocationType.stop;

  /// The area worth showing next to the name: the one the geocoder marked as
  /// distinguishing, else the default one.
  Area? get displayArea {
    for (final area in areas) {
      if (area.unique) return area;
    }
    for (final area in areas) {
      if (area.isDefault) return area;
    }
    return null;
  }

  /// OSM admin level of a region: a state, a Land, a French région.
  static const double _regionLevel = 4;

  /// The most specific level still read as a district: an Ortsteil, a
  /// quartier. Anything finer is a neighbourhood nobody asks for by name.
  static const double _finestDistrictLevel = 10;

  /// A city, town or village rather than something in one.
  bool get isSettlement => category?.startsWith('place') ?? false;

  /// The area MOTIS marks for display by default: the city, usually.
  Area? get cityArea {
    for (final area in areas) {
      if (area.isDefault) return area;
    }
    return null;
  }

  /// The most specific area inside [cityArea], down to a district.
  ///
  /// Null for a settlement: the district of a city's centre point is not
  /// where the city is.
  Area? get districtArea {
    final city = cityArea;
    if (city == null || isSettlement) return null;
    Area? district;
    for (final area in areas) {
      final level = area.adminLevel;
      if (level <= city.adminLevel || level > _finestDistrictLevel) continue;
      if (district == null || level > district.adminLevel) district = area;
    }
    return district;
  }

  /// The state or region the match lies in.
  Area? get regionArea {
    for (final area in areas) {
      if (area.adminLevel == _regionLevel) return area;
    }
    return null;
  }

  /// Street and house number joined, for address matches.
  String? get addressLine {
    if (street == null || street!.isEmpty) return null;
    if (houseNumber == null || houseNumber!.isEmpty) return street;
    return '$street $houseNumber';
  }

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    type: LocationType.fromWire(json['type']),
    name: asString(json['name']) ?? '',
    id: asString(json['id']) ?? '',
    lat: asDouble(json['lat']) ?? 0.0,
    lon: asDouble(json['lon']) ?? 0.0,
    score: asDouble(json['score']) ?? 0.0,
    category: asString(json['category']),
    tokens: [
      if (json['tokens'] is List)
        for (final entry in json['tokens'] as List)
          if (MatchToken.fromJson(entry) case final token?) token,
    ],
    areas: asList(json['areas'], Area.fromJson),
    level: asDouble(json['level']),
    street: asString(json['street']),
    houseNumber: asString(json['houseNumber']),
    country: asString(json['country']),
    zip: asString(json['zip']),
    tz: asString(json['tz']),
    modes: [
      if (json['modes'] is List)
        for (final entry in json['modes'] as List)
          if (TransitMode.fromWire(entry) case final mode?) mode,
    ],
    importance: asDouble(json['importance']),
  );
}
