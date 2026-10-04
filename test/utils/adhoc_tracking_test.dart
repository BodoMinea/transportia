import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/adhoc_tracking.dart';

/// The real `/trip` capture: the S7, Ahrensfelde to Potsdam.
Leg _wholeTrip() {
  final json =
      jsonDecode(File('test/fixtures/transitous/trip.json').readAsStringSync())
          as Map<String, dynamic>;
  return Itinerary.fromJson(json).legs.single;
}

void main() {
  group('boardingIndexOn', () {
    test('finds the stop by its id', () {
      final trip = _wholeTrip();
      final ostkreuz = trip.stopSequence.firstWhere(
        (s) => s.name == 'S Ostkreuz Bhf (Berlin)',
      );

      final index = boardingIndexOn(
        trip,
        TransitPlace(
          name: 'listed differently',
          lat: 0,
          lon: 0,
          stopId: ostkreuz.stopId,
        ),
      );

      expect(index, trip.stopSequence.indexOf(ostkreuz));
    });

    test('finds the first and last stop', () {
      final trip = _wholeTrip();

      expect(boardingIndexOn(trip, trip.from), 0);
      expect(boardingIndexOn(trip, trip.to), trip.stopSequence.length - 1);
    });

    test('falls back to the nearest stop when the id is unknown', () {
      final trip = _wholeTrip();
      final wannsee = trip.stopSequence.firstWhere(
        (s) => s.name == 'S Wannsee Bhf (Berlin)',
      );

      // A stop the trip does not name, standing a few metres from Wannsee.
      final index = boardingIndexOn(
        trip,
        TransitPlace(
          name: 'Wannsee platform 2',
          stopId: 'another-feed:wannsee-2',
          lat: wannsee.lat + 0.0001,
          lon: wannsee.lon,
        ),
      );

      expect(index, trip.stopSequence.indexOf(wannsee));
    });
  });
}
