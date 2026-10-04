import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo_utils.dart';

List<LatLng> decodePolyline(String encoded, int precision) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;
  final double factor = math.pow(10, -precision).toDouble();

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat * factor, lng * factor));
  }
  return points;
}

/// Inverse of [decodePolyline]: encodes [points] at the same [precision].
String encodePolyline(List<LatLng> points, int precision) {
  final factor = math.pow(10, precision).toDouble();
  final buffer = StringBuffer();
  var previousLat = 0;
  var previousLng = 0;

  for (final point in points) {
    final lat = (point.latitude * factor).round();
    final lng = (point.longitude * factor).round();
    _writePolylineValue(lat - previousLat, buffer);
    _writePolylineValue(lng - previousLng, buffer);
    previousLat = lat;
    previousLng = lng;
  }
  return buffer.toString();
}

void _writePolylineValue(int value, StringBuffer buffer) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}

/// The part of [points] running from the point nearest [from] to the one
/// nearest [to], or null when that cannot be told: nothing to slice, or the
/// two ends not in order along the line.
///
/// For a route shape that covers more than the stretch someone travels, such
/// as a whole trip when they ride only part of it. Null rather than the
/// unsliced line, because a map drawing the whole line for a short ride is
/// wrong in a way a straight segment is not.
List<LatLng>? slicePolyline(List<LatLng> points, LatLng from, LatLng to) {
  if (points.length < 2) return null;

  int nearest(LatLng target) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final distance = coordinateDistanceInMeters(
        points[i].latitude,
        points[i].longitude,
        target.latitude,
        target.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  final start = nearest(from);
  final end = nearest(to);
  if (start >= end) return null;
  return points.sublist(start, end + 1);
}
