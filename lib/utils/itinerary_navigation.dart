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

/// Fraction (0..1) of [waypoints]' total length completed, given the
/// furthest waypoint index reached ([stopIndex]) and the live position —
/// interpolates within the current stop-to-stop segment by straight-line
/// distance from its start, so it moves continuously with GPS rather than
/// jumping only when a new stop is reached. Same waypoint list works for
/// both walk and transit legs.
double legDistanceProgress(List<LatLng> waypoints, LatLng? pos, int stopIndex) {
  if (waypoints.length < 2) return 0;

  final segmentLengths = <double>[];
  double total = 0;
  for (int i = 0; i < waypoints.length - 1; i++) {
    final length = coordinateDistanceInMeters(
      waypoints[i].latitude,
      waypoints[i].longitude,
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
    );
    segmentLengths.add(length);
    total += length;
  }
  if (total <= 0) return 0;

  double completed = 0;
  for (int i = 0; i < stopIndex && i < segmentLengths.length; i++) {
    completed += segmentLengths[i];
  }

  if (pos != null && stopIndex < segmentLengths.length) {
    final segmentLength = segmentLengths[stopIndex];
    if (segmentLength > 0) {
      final distanceFromSegmentStart = coordinateDistanceInMeters(
        waypoints[stopIndex].latitude,
        waypoints[stopIndex].longitude,
        pos.latitude,
        pos.longitude,
      );
      completed += distanceFromSegmentStart.clamp(0, segmentLength);
    }
  }

  return (completed / total).clamp(0.0, 1.0);
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
/// background tracking notification so they never drift apart — except for
/// exactly one stop left, where [nextStopLabel] lets each surface phrase it
/// its own way (e.g. "Next stop" vs. "Your stop is next").
String? progressLabel({
  double? remainingWalkMeters,
  int? remainingStops,
  String nextStopLabel = 'Next stop',
}) {
  if (remainingWalkMeters != null) {
    return '${formatWalkRemaining(remainingWalkMeters)} to go';
  }
  if (remainingStops != null) {
    if (remainingStops <= 0) return 'Arriving now';
    if (remainingStops == 1) return nextStopLabel;
    return '$remainingStops stops to go';
  }
  return null;
}
