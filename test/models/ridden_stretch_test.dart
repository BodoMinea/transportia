import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/ridden_stretch.dart';

/// The real `/trip` capture: the S7, Ahrensfelde to Potsdam.
Leg _wholeTrip() {
  final json =
      jsonDecode(File('test/fixtures/transitous/trip.json').readAsStringSync())
          as Map<String, dynamic>;
  return Itinerary.fromJson(json).legs.single;
}

TransitPlace _named(String name) => TransitPlace(name: name, lat: 0, lon: 0);

void main() {
  group('Leg.stopRangeBetween', () {
    test('gives the indices of the two ends', () {
      final trip = _wholeTrip();

      final range = trip.stopRangeBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      )!;

      expect(trip.stopSequence[range.start].name, 'S Ostkreuz Bhf (Berlin)');
      expect(trip.stopSequence[range.end].name, 'S Wannsee Bhf (Berlin)');
      expect(range.start, lessThan(range.end));
    });

    test('covers the whole trip from end to end', () {
      final trip = _wholeTrip();

      final range = trip.stopRangeBetween(trip.from, trip.to)!;

      expect(range.start, 0);
      expect(range.end, trip.stopSequence.length - 1);
    });

    test('is null for a stop the trip does not call at', () {
      final trip = _wholeTrip();

      expect(
        trip.stopRangeBetween(
          _named('Flughafen BER'),
          _named('S Wannsee Bhf (Berlin)'),
        ),
        isNull,
      );
      expect(
        trip.stopRangeBetween(
          _named('S Ostkreuz Bhf (Berlin)'),
          _named('Flughafen BER'),
        ),
        isNull,
      );
    });

    test('is null with the ends the wrong way round', () {
      final trip = _wholeTrip();

      expect(
        trip.stopRangeBetween(
          _named('S Wannsee Bhf (Berlin)'),
          _named('S Ostkreuz Bhf (Berlin)'),
        ),
        isNull,
      );
    });
  });

  group('RiddenStretch.rangeOn', () {
    test('is the stretch a leg of a journey rides', () {
      final trip = _wholeTrip();
      final stretch = RiddenStretch(
        from: _named('S Ostkreuz Bhf (Berlin)'),
        to: _named('S Wannsee Bhf (Berlin)'),
      );

      final range = stretch.rangeOn(trip)!;

      expect(trip.stopSequence[range.start].name, 'S Ostkreuz Bhf (Berlin)');
      expect(trip.stopSequence[range.end].name, 'S Wannsee Bhf (Berlin)');
    });

    test('is made from the ends of a leg', () {
      final trip = _wholeTrip();
      final sliced = trip.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      final range = RiddenStretch.ofLeg(sliced).rangeOn(trip)!;

      expect(trip.stopSequence[range.start].name, 'S Ostkreuz Bhf (Berlin)');
      expect(trip.stopSequence[range.end].name, 'S Wannsee Bhf (Berlin)');
    });

    test('is null when the whole trip is ridden: nothing to tell apart', () {
      final trip = _wholeTrip();

      expect(RiddenStretch.ofLeg(trip).rangeOn(trip), isNull);
    });

    test('is null when the trip does not call there: nothing is guessed', () {
      final trip = _wholeTrip();
      final stretch = RiddenStretch(
        from: _named('Somewhere else'),
        to: _named('S Wannsee Bhf (Berlin)'),
      );

      expect(stretch.rangeOn(trip), isNull);
    });
  });
}
