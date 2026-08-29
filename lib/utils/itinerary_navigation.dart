import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/itinerary.dart';
import 'geo_utils.dart';

List<LatLng> stopWaypoints(Leg leg) {
  return [
    LatLng(leg.fromLat, leg.fromLon),
    for (final stop in leg.intermediateStops) LatLng(stop.lat, stop.lon),
    LatLng(leg.toLat, leg.toLon),
  ];
}

int advanceStopIndex(
  List<LatLng> waypoints,
  LatLng pos,
  int previousIndex, {
  double thresholdMeters = 120,
}) {
  int best = previousIndex;
  for (int i = previousIndex; i < waypoints.length; i++) {
    final distance = coordinateDistanceInMeters(
      pos.latitude,
      pos.longitude,
      waypoints[i].latitude,
      waypoints[i].longitude,
    );
    if (distance <= thresholdMeters) best = i;
  }
  return best;
}

double minDistanceToRoute(List<List<LatLng>> legGeometries, LatLng pos) {
  double best = double.infinity;
  for (final geometry in legGeometries) {
    for (final point in geometry) {
      final distance = coordinateDistanceInMeters(
        pos.latitude,
        pos.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < best) best = distance;
    }
  }
  return best;
}

String formatWalkRemaining(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

/// Shared "N stops/m to go" wording, used by both the in-app carousel and the
/// background tracking notification so they never drift apart.
String? progressLabel({double? remainingWalkMeters, int? remainingStops}) {
  if (remainingWalkMeters != null) {
    return '${formatWalkRemaining(remainingWalkMeters)} to go';
  }
  if (remainingStops != null) {
    if (remainingStops <= 0) return 'Arriving now';
    return '$remainingStops ${remainingStops == 1 ? 'stop' : 'stops'} to go';
  }
  return null;
}
