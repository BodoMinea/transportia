import 'package:flutter/widgets.dart';

import '../../services/transitous_geocode_service.dart';
import '../../utils/place_icons.dart';

/// The map image a result is drawn with: one per icon, so a bus stop on the
/// map looks as it does in the list.
String resultPinImageId(IconData icon) => 'result-pin-${icon.codePoint}';

/// The icon a result is drawn with, in the list and on the map alike.
IconData resultPinIcon(TransitousLocationSuggestion result) =>
    placeIcon(result.type, modes: result.modes);

/// Search results as a GeoJSON feature collection for the pins layer.
///
/// Each feature's `rank` is its index in [results], which is how a tapped
/// pin is found again. `sortKey` puts the better-ranked name first where two
/// collide, and the [selected] one above all.
Map<String, dynamic> resultPinFeatures(
  List<TransitousLocationSuggestion> results, {
  int? selected,
}) => {
  'type': 'FeatureCollection',
  'features': [
    for (var i = 0; i < results.length; i++)
      {
        'type': 'Feature',
        'id': i,
        'properties': {
          'rank': i,
          'name': results[i].name,
          'icon': resultPinImageId(resultPinIcon(results[i])),
          'selected': i == selected,
          'sortKey': i == selected ? -1 : i,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [results[i].lon, results[i].lat],
        },
      },
  ],
};
