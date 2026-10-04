import '../services/transitous_geocode_service.dart';
import '../utils/geo_utils.dart';
import 'my_location.dart';

/// One end of a search the rider ran: a place, or "where I am".
///
/// Only what is needed to put the field back as it was. My Location carries
/// no position of its own, since it is read from the device when the search
/// is run, so repeating the search later starts from wherever the rider is
/// then.
class RecentSearchEnd {
  const RecentSearchEnd({
    required this.name,
    required this.lat,
    required this.lon,
    this.type = 'PLACE',
    this.stopId,
    this.isMyLocation = false,
  });

  /// [suggestion] as it stood when the search was run.
  factory RecentSearchEnd.of(TransitousLocationSuggestion suggestion) {
    if (suggestion.isMyLocation) return RecentSearchEnd.myLocation;
    return RecentSearchEnd(
      name: suggestion.name,
      lat: suggestion.lat,
      lon: suggestion.lon,
      type: suggestion.type,
      stopId: suggestion.stopId,
    );
  }

  static const RecentSearchEnd myLocation = RecentSearchEnd(
    name: myLocationName,
    lat: 0,
    lon: 0,
    isMyLocation: true,
  );

  final String name;
  final double lat;
  final double lon;

  /// What the geocoder called it — `STOP`, `ADDRESS`, `PLACE` — so a station
  /// comes back as one.
  final String type;
  final String? stopId;
  final bool isMyLocation;

  /// The field's selection, as it would be had the rider picked it again.
  TransitousLocationSuggestion toSuggestion() {
    if (isMyLocation) return myLocationSuggestion;
    return TransitousLocationSuggestion(
      id: 'recent-search-${coordKey(lat, lon)}',
      name: name,
      lat: lat,
      lon: lon,
      type: type,
      stopId: stopId,
    );
  }

  /// Three decimals is ~100 m: the same stop reached from a slightly
  /// different pick is the same place to the rider.
  static const int _identityDecimals = 3;

  String get identity =>
      isMyLocation ? 'here' : coordKey(lat, lon, decimals: _identityDecimals);

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'type': type,
    if (stopId != null) 'stopId': stopId,
    if (isMyLocation) 'isMyLocation': true,
  };

  factory RecentSearchEnd.fromJson(Map<String, dynamic> json) {
    if (json['isMyLocation'] == true) return RecentSearchEnd.myLocation;
    return RecentSearchEnd(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: json['type'] as String? ?? 'PLACE',
      stopId: json['stopId'] as String?,
    );
  }
}

/// A search the rider ran, kept to run again.
///
/// It is the two ends and nothing else, deliberately. A saved or recent *trip*
/// is one connection that was opened, shown again as it was; this is only the
/// question, asked afresh each time, so the answer is always today's.
class RecentSearch {
  const RecentSearch({
    required this.from,
    required this.to,
    required this.searchedAt,
  });

  final RecentSearchEnd from;
  final RecentSearchEnd to;
  final DateTime searchedAt;

  /// Identity of a search: the same two ends. Running it again moves it to
  /// the top rather than listing it twice.
  String get identity => '${from.identity}>${to.identity}';

  Map<String, dynamic> toJson() => {
    'from': from.toJson(),
    'to': to.toJson(),
    'searchedAt': searchedAt.toIso8601String(),
  };

  factory RecentSearch.fromJson(Map<String, dynamic> json) => RecentSearch(
    from: RecentSearchEnd.fromJson(json['from'] as Map<String, dynamic>),
    to: RecentSearchEnd.fromJson(json['to'] as Map<String, dynamic>),
    searchedAt: DateTime.parse(json['searchedAt'] as String),
  );
}
