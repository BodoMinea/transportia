import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/ridden_stretch.dart';
import 'package:transportia/utils/geo_utils.dart';
import 'package:transportia/utils/polyline_utils.dart';
import 'package:transportia/utils/ridden_line.dart';

/// The real `/trip` capture: the S7, Ahrensfelde to Potsdam, with its shape.
Leg _wholeTrip() {
  final json =
      jsonDecode(File('test/fixtures/transitous/trip.json').readAsStringSync())
          as Map<String, dynamic>;
  return Itinerary.fromJson(json).legs.single;
}

List<LatLng> _lineOf(Leg leg) =>
    decodePolyline(leg.legGeometry!.points, leg.legGeometry!.precision);

TransitPlace _named(String name) => TransitPlace(name: name, lat: 0, lon: 0);

final RiddenStretch _ostkreuzToWannsee = RiddenStretch(
  from: _named('S Ostkreuz Bhf (Berlin)'),
  to: _named('S Wannsee Bhf (Berlin)'),
);

double _metres(LatLng point, TransitPlace place) => coordinateDistanceInMeters(
  point.latitude,
  point.longitude,
  place.lat,
  place.lon,
);

void main() {
  group('the part of a trip\'s line that a journey rides', () {
    test('is shorter than the whole line, and part of it', () {
      final trip = _wholeTrip();
      final line = _lineOf(trip);

      final part = riddenPartOfLine(trip, line, _ostkreuzToWannsee)!;

      expect(part.length, lessThan(line.length));
      expect(part.length, greaterThan(1));
      // Points of the line itself, in its order, not new ones.
      final start = line.indexOf(part.first);
      expect(line.sublist(start, start + part.length), part);
    });

    test('runs from the boarding stop to the stop it gets off at', () {
      final trip = _wholeTrip();
      final part = riddenPartOfLine(trip, _lineOf(trip), _ostkreuzToWannsee)!;

      final ostkreuz = trip.stopSequence.firstWhere(
        (s) => s.name == 'S Ostkreuz Bhf (Berlin)',
      );
      final wannsee = trip.stopSequence.firstWhere(
        (s) => s.name == 'S Wannsee Bhf (Berlin)',
      );
      expect(_metres(part.first, ostkreuz), lessThan(150));
      expect(_metres(part.last, wannsee), lessThan(150));
    });

    test('is nothing when no stretch was given: the trip is one', () {
      final trip = _wholeTrip();

      expect(riddenPartOfLine(trip, _lineOf(trip), null), isNull);
    });

    test('is nothing when the whole trip is ridden', () {
      final trip = _wholeTrip();

      expect(
        riddenPartOfLine(trip, _lineOf(trip), RiddenStretch.ofLeg(trip)),
        isNull,
      );
    });

    test('is nothing when the trip does not call where the stretch does', () {
      final trip = _wholeTrip();
      final elsewhere = RiddenStretch(
        from: _named('Flughafen BER'),
        to: _named('S Wannsee Bhf (Berlin)'),
      );

      expect(riddenPartOfLine(trip, _lineOf(trip), elsewhere), isNull);
    });

    test('is nothing for a line with no shape to cut', () {
      final trip = _wholeTrip();

      expect(riddenPartOfLine(trip, const [], _ostkreuzToWannsee), isNull);
    });
  });
}
