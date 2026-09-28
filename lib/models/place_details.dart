/// An OpenStreetMap element, as MOTIS names where a place came from.
///
/// MOTIS gives a place the id `node/[578429141]`, `way/[60541581]` or
/// `relation/[…]`; Nominatim looks the same element up as `N578429141`.
class OsmRef {
  const OsmRef(this.type, this.id);

  /// `N`, `W` or `R`, as Nominatim's `osm_ids` wants it.
  final String type;
  final int id;

  static final RegExp _motisId = RegExp(r'^(node|way|relation)/\[(\d+)\]$');

  static const Map<String, String> _types = {
    'node': 'N',
    'way': 'W',
    'relation': 'R',
  };

  /// Null for anything else: a stop's feed id, an address MOTIS invented.
  static OsmRef? parse(String motisId) {
    final match = _motisId.firstMatch(motisId.trim());
    if (match == null) return null;
    final id = int.tryParse(match.group(2)!);
    if (id == null) return null;
    return OsmRef(_types[match.group(1)]!, id);
  }

  /// The id Nominatim's lookup takes.
  String get lookupId => '$type$id';

  @override
  bool operator ==(Object other) =>
      other is OsmRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// What OpenStreetMap knows about a place beyond its name: the facts a
/// details sheet shows. Each is null when the map does not say.
class PlaceDetails {
  const PlaceDetails({
    this.street,
    this.locality,
    this.openingHours,
    this.phone,
    this.website,
    this.wheelchair,
    this.level,
  });

  /// "Schönhauser Allee 10-11".
  final String? street;

  /// "10119 Berlin".
  final String? locality;

  /// In OSM's own syntax, e.g. `Mo-Sa 07:00-23:30`.
  final String? openingHours;

  final String? phone;
  final String? website;

  /// `yes`, `limited` or `no`.
  final String? wheelchair;

  /// The floor, e.g. `0` or `2`.
  final String? level;

  bool get isEmpty =>
      street == null &&
      locality == null &&
      openingHours == null &&
      phone == null &&
      website == null &&
      wheelchair == null &&
      level == null;

  /// One result of Nominatim's `/lookup` with `addressdetails` and
  /// `extratags`.
  ///
  /// Mappers write the same fact under more than one key; the plain key
  /// wins over its `contact:` form, as OSM's wiki recommends the plain one.
  factory PlaceDetails.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'];
    final tags = json['extratags'];
    String? pick(Object? map, List<String> keys) {
      if (map is! Map) return null;
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    String? join(List<String?> parts) {
      final present = [
        for (final p in parts)
          if (p != null) p,
      ];
      return present.isEmpty ? null : present.join(' ');
    }

    final road = pick(address, const ['road', 'pedestrian', 'footway']);
    return PlaceDetails(
      street: road == null
          ? null
          : join([
              road,
              pick(address, const ['house_number']),
            ]),
      locality: join([
        pick(address, const ['postcode']),
        pick(address, const ['city', 'town', 'village', 'municipality']),
      ]),
      openingHours: pick(tags, const ['opening_hours']),
      phone: pick(tags, const ['phone', 'contact:phone']),
      website: pick(tags, const ['website', 'contact:website', 'url']),
      wheelchair: pick(tags, const ['wheelchair']),
      level: pick(tags, const ['level']),
    );
  }
}
