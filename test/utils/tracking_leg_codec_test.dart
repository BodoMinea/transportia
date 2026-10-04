import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/itinerary_leg_utils.dart';
import 'package:transportia/utils/tracking_leg_codec.dart';

import '../support/plan_fixtures.dart';

List<DisplayLegInfo> _legs() => buildDisplayLegs(
  Itinerary.fromJson(
    planItineraryJson(departure: DateTime.utc(2026, 9, 28, 8)),
  ).legs,
);

/// What the service actually receives: the message goes through the platform
/// channel, so it has to survive being written as JSON.
Map<String, dynamic> _overTheWire(DisplayLegInfo entry) =>
    jsonDecode(jsonEncode(displayLegToJson(entry))) as Map<String, dynamic>;

void main() {
  group('a leg sent to the background service', () {
    test('comes back with where it goes and when', () {
      final ride = _legs().firstWhere((e) => e.leg.mode == 'REGIONAL_RAIL');

      final back = displayLegFromJson(_overTheWire(ride)).leg;

      expect(back.mode, ride.leg.mode);
      expect(back.fromName, ride.leg.fromName);
      expect(back.toName, ride.leg.toName);
      expect(back.fromLat, ride.leg.fromLat);
      expect(back.toLon, ride.leg.toLon);
      expect(back.fromStopId, ride.leg.fromStopId);
      expect(back.startTime, ride.leg.startTime);
      expect(back.endTime, ride.leg.endTime);
      expect(back.duration, ride.leg.duration);
      expect(back.realTime, isTrue);
    });

    test('keeps the stops in between, in order', () {
      final ride = _legs().firstWhere((e) => e.leg.mode == 'REGIONAL_RAIL');

      final back = displayLegFromJson(_overTheWire(ride)).leg;

      expect(back.intermediateStops.map((s) => s.name), [
        'Ostkreuz',
        'Schönefeld',
      ]);
      expect(back.intermediateStops.first.lat, 52.503);
      expect(back.stopSequence, hasLength(4));
    });

    test('keeps what the notification calls it', () {
      final ride = _legs().firstWhere((e) => e.leg.mode == 'REGIONAL_RAIL');

      final back = displayLegFromJson(_overTheWire(ride)).leg;

      expect(back.displayName, 'RE7');
      expect(back.headsign, 'Flughafen BER');
    });

    test('keeps a walk\'s distance, which is how far it has to go', () {
      final walk = _legs().first;
      expect(walk.leg.mode, 'WALK');

      final back = displayLegFromJson(_overTheWire(walk)).leg;

      expect(back.distance, 420.0);
    });

    test('keeps which leg it was and whether it is a change', () {
      for (final entry in _legs()) {
        final back = displayLegFromJson(_overTheWire(entry));

        expect(back.originalIndex, entry.originalIndex);
        expect(back.type, entry.type);
      }
    });

    test('does without what a leg may not have', () {
      final bare = DisplayLegInfo(
        leg: Leg(
          mode: 'WALK',
          from: const TransitPlace(name: 'A', lat: 1, lon: 2),
          to: const TransitPlace(name: 'B', lat: 3, lon: 4),
          startTime: DateTime.utc(2026, 9, 28, 8),
          endTime: DateTime.utc(2026, 9, 28, 8, 5),
          duration: 300,
        ),
        originalIndex: 0,
      );

      final back = displayLegFromJson(_overTheWire(bare)).leg;

      expect(back.distance, isNull);
      expect(back.displayName, isNull);
      expect(back.scheduledStartTime, isNull);
      expect(back.fromStopId, isNull);
      expect(back.intermediateStops, isEmpty);
    });
  });
}
