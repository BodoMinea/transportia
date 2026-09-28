/// The line under a place's name in a result list:
/// "1.2 km · Prenzlauer Berg, Berlin", "7592 km · Texas, US".
///
/// The areas tell apart places that share a name: the district and city,
/// or, with no district, the region above the city — eight towns called
/// Paris in the US are told apart by their states. An area that repeats the
/// name, or an earlier area, says nothing and is dropped. The country only
/// shows when it is not [homeCountry], the rider's own.
///
/// [metres] is how far the place is from the rider; null when that is not
/// known, and the distance is left out.
String placeCaption({
  required String name,
  String? district,
  String? city,
  String? region,
  String? country,
  String? homeCountry,
  double? metres,
}) {
  final areas = <String>[];
  void add(String? area) {
    if (area == null) return;
    final trimmed = area.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    if (lower == name.trim().toLowerCase()) return;
    if (areas.any((a) => a.toLowerCase() == lower)) return;
    areas.add(trimmed);
  }

  add(district);
  add(city);
  if (district == null || district.trim().isEmpty) add(region);
  final isAbroad =
      country != null &&
      country.isNotEmpty &&
      country.toUpperCase() != homeCountry?.toUpperCase();
  if (isAbroad) add(country);

  return [
    if (metres != null) formatPlaceDistance(metres),
    if (areas.isNotEmpty) areas.join(', '),
  ].join(' · ');
}

/// Metres under a kilometre, one decimal under ten, whole kilometres above:
/// as precise as a place's distance is worth reading.
String formatPlaceDistance(double metres) {
  const metresPerKilometre = 1000.0;
  const oneDecimalBelowKm = 10.0;
  // Under a kilometre, metres are rounded to tens: nobody walks 347 m.
  const metreStep = 10;
  // Rounded before choosing the unit, so 996 m reads 1.0 km, not 1000 m.
  final roundedMetres = (metres / metreStep).round() * metreStep;
  if (roundedMetres < metresPerKilometre) return '$roundedMetres m';
  final km = metres / metresPerKilometre;
  final tenths = (km * 10).round() / 10;
  if (tenths < oneDecimalBelowKm) return '${tenths.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// What kind of place MOTIS says this is, for a person: `supermarket_14`
/// reads "Supermarket", `fast_food_16` "Fast food".
///
/// MOTIS appends a number to its category names; the rest is OSM's tag
/// value. Null for a settlement, whose name already says what it is, and
/// for `none` or nothing.
String? categoryLabel(String? category) {
  if (category == null) return null;
  final words = category
      .replaceFirst(RegExp(r'_\d+$'), '')
      .split('_')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  if (words.first == 'place' || words.first == 'none') return null;
  final text = words.join(' ');
  return text[0].toUpperCase() + text.substring(1);
}
