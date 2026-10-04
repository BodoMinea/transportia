import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/itinerary.dart';
import '../models/ridden_stretch.dart';
import 'polyline_utils.dart';

/// The part of [line], the drawn shape of [leg], that [ridden] rides, or null
/// when nothing is to be told apart: no stretch was given, it is not on this
/// leg, it is all of it, or the line cannot be cut sensibly.
///
/// A map draws [line] light and this part over it in full, so the rider can
/// see where the rest of the trip goes without taking it for their own.
List<LatLng>? riddenPartOfLine(
  Leg leg,
  List<LatLng> line,
  RiddenStretch? ridden,
) {
  final range = ridden?.rangeOn(leg);
  if (range == null) return null;

  final stops = leg.stopSequence;
  return slicePolyline(
    line,
    LatLng(stops[range.start].lat, stops[range.start].lon),
    LatLng(stops[range.end].lat, stops[range.end].lon),
  );
}
