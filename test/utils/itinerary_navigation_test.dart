import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/itinerary_navigation.dart';

/// Four stops a kilometre apart on a line of latitude, near enough that
/// metres can be read off the degrees.
const double _degreesPerKilometre = 1 / 111.32;
final List<LatLng> _line = [
  for (var i = 0; i < 4; i++) LatLng(0, i * _degreesPerKilometre),
];

LatLng _at(double kilometres) => LatLng(0, kilometres * _degreesPerKilometre);

void main() {
  group('the stops of a leg', () {
    test('run from where it starts to where it ends', () {
      final leg = Leg(
        mode: 'BUS',
        from: const TransitPlace(name: 'A', lat: 1, lon: 1),
        to: const TransitPlace(name: 'C', lat: 3, lon: 3),
        intermediateStops: const [TransitPlace(name: 'B', lat: 2, lon: 2)],
        startTime: DateTime.utc(2026),
        endTime: DateTime.utc(2026),
        duration: 0,
      );

      expect(stopWaypoints(leg), [
        const LatLng(1, 1),
        const LatLng(2, 2),
        const LatLng(3, 3),
      ]);
    });
  });

  group('advanceStopIndex', () {
    test('stays put while no stop is reached', () {
      expect(advanceStopIndex(_line, _at(0.5), 0), 0);
    });

    test('moves to a stop the rider is at', () {
      expect(advanceStopIndex(_line, _at(1.05), 0), 1);
    });

    test('takes the furthest stop within reach', () {
      // Two stops 100 m apart, both within the 120 m threshold.
      final close = [_at(0), _at(1), _at(1.1)];

      expect(advanceStopIndex(close, _at(1.05), 0), 2);
    });

    test('never goes back past where it already was', () {
      expect(advanceStopIndex(_line, _at(0), 2), 2);
    });
  });

  group('legDistanceProgress', () {
    test('is nothing at the start and all of it at the end', () {
      expect(legDistanceProgress(_line, _at(0), 0), 0);
      expect(legDistanceProgress(_line, _at(3), 3), 1);
    });

    test('moves between stops, not only at them', () {
      // Half way along the second of three kilometre-long segments.
      expect(
        legDistanceProgress(_line, _at(1.5), 1),
        closeTo(0.5 / 3 + 1 / 3, 0.01),
      );
    });

    test('counts the stops already reached', () {
      expect(legDistanceProgress(_line, null, 2), closeTo(2 / 3, 0.01));
    });

    test('is capped at the whole leg however far the fix strays', () {
      expect(legDistanceProgress(_line, _at(40), 2), lessThanOrEqualTo(1));
    });

    test('is nothing for a line with no length', () {
      expect(legDistanceProgress([_at(0)], _at(0), 0), 0);
      expect(legDistanceProgress([_at(1), _at(1)], _at(1), 0), 0);
    });
  });

  group('minDistanceToRoute', () {
    test('is the distance to the nearest point of any leg', () {
      final metres = minDistanceToRoute([
        [_at(0), _at(1)],
        [_at(5)],
      ], _at(1.2));

      expect(metres, closeTo(200, 5));
    });

    test('is infinite with no route', () {
      expect(minDistanceToRoute(const [], _at(0)), double.infinity);
    });
  });

  group('the words for progress', () {
    test('a walk is the distance left', () {
      expect(progressLabel(remainingWalkMeters: 85.4), '85 m to go');
      expect(progressLabel(remainingWalkMeters: 1500), '1.50 km to go');
    });

    test('a ride is the stops left', () {
      expect(progressLabel(remainingStops: 5), '5 stops to go');
      expect(progressLabel(remainingStops: 0), 'Arriving now');
    });

    test('one stop left is said as each surface likes', () {
      expect(progressLabel(remainingStops: 1), 'Next stop');
      expect(
        progressLabel(remainingStops: 1, nextStopLabel: 'Your stop is next'),
        'Your stop is next',
      );
    });

    test('nothing known is nothing said', () {
      expect(progressLabel(), isNull);
    });
  });

  group('virtualRemaining', () {
    final now = DateTime.utc(2026, 9, 28, 8, 30);

    /// A 40 minute ride the timetable has arriving at [arrivesIn] from now.
    Leg ride({
      Duration arrivesIn = const Duration(minutes: 20),
      bool scheduled = true,
      String mode = 'REGIONAL_RAIL',
    }) {
      final end = now.add(arrivesIn);
      final scheduledStart = DateTime.utc(2026, 9, 28, 8, 0);
      final scheduledEnd = scheduledStart.add(const Duration(minutes: 40));
      return Leg(
        mode: mode,
        from: const TransitPlace(name: 'A', lat: 1, lon: 1),
        to: const TransitPlace(name: 'B', lat: 2, lon: 2),
        startTime: end.subtract(const Duration(minutes: 40)),
        endTime: end,
        scheduledStartTime: scheduled ? scheduledStart : null,
        scheduledEndTime: scheduled ? scheduledEnd : null,
        duration: const Duration(minutes: 40).inSeconds,
      );
    }

    Duration? remaining(
      Leg leg, {
      double progress = 0.5,
      int fixes = 10,
      bool latched = false,
    }) => virtualRemaining(
      leg: leg,
      legProgress: progress,
      fixes: fixes,
      now: now,
      latched: latched,
    );

    test('is what is left of the scheduled length, by how far along', () {
      // Arrives in 20 min by the timetable; half way through a 40 minute ride
      // with 20 min left would agree, so make the timetable 10 minutes out.
      final leg = ride(arrivesIn: const Duration(minutes: 30));

      expect(remaining(leg), const Duration(minutes: 20));
    });

    test('is a share of the whole, not of what is left on the clock', () {
      final leg = ride(arrivesIn: const Duration(minutes: 2));

      expect(remaining(leg, progress: 0.25), const Duration(minutes: 30));
      expect(remaining(leg, progress: 0.75), const Duration(minutes: 10));
    });

    test('is nothing while the pace agrees with the timetable', () {
      // 20 min left by the pace, 20 by the timetable.
      expect(remaining(ride()), isNull);
    });

    test('is nothing within the five minutes of margin, either way', () {
      expect(remaining(ride(arrivesIn: const Duration(minutes: 24))), isNull);
      expect(remaining(ride(arrivesIn: const Duration(minutes: 16))), isNull);
      expect(
        remaining(ride(arrivesIn: const Duration(minutes: 25))),
        isNull,
        reason: 'five minutes is the margin, not more than it',
      );
    });

    test('is given once the pace is more than five minutes from it', () {
      expect(
        remaining(ride(arrivesIn: const Duration(minutes: 26))),
        const Duration(minutes: 20),
      );
      expect(
        remaining(ride(arrivesIn: const Duration(minutes: 14))),
        const Duration(minutes: 20),
      );
    });

    test('covers boarding a vehicle that is earlier or later', () {
      final laterVehicle = ride(arrivesIn: const Duration(minutes: 5));
      final earlierVehicle = ride(arrivesIn: const Duration(minutes: 50));

      expect(remaining(laterVehicle), isNotNull);
      expect(remaining(earlierVehicle), isNotNull);
    });

    test('waits for ten fixes', () {
      final leg = ride(arrivesIn: const Duration(minutes: 5));

      expect(remaining(leg, fixes: 9), isNull);
      expect(remaining(leg, fixes: 10), isNotNull);
    });

    test('waits for three percent of the ride', () {
      final leg = ride(arrivesIn: const Duration(minutes: 5));

      expect(remaining(leg, progress: 0.029), isNull);
      expect(remaining(leg, progress: 0.03), isNotNull);
    });

    test('is nothing for a walk', () {
      final walk = ride(arrivesIn: const Duration(minutes: 5), mode: 'WALK');

      expect(remaining(walk), isNull);
    });

    test('uses the leg\'s duration where there is no schedule to read', () {
      final leg = ride(arrivesIn: const Duration(minutes: 5), scheduled: false);

      expect(remaining(leg), const Duration(minutes: 20));
    });

    test('uses the scheduled length, not the live one', () {
      // A delayed ride's live times stretch it; the pace is read against the
      // length it was timetabled at.
      final end = now.add(const Duration(minutes: 5));
      final leg = Leg(
        mode: 'BUS',
        from: const TransitPlace(name: 'A', lat: 1, lon: 1),
        to: const TransitPlace(name: 'B', lat: 2, lon: 2),
        startTime: end.subtract(const Duration(minutes: 70)),
        endTime: end,
        scheduledStartTime: DateTime.utc(2026, 9, 28, 8, 0),
        scheduledEndTime: DateTime.utc(2026, 9, 28, 8, 40),
        duration: const Duration(minutes: 70).inSeconds,
      );

      expect(remaining(leg), const Duration(minutes: 20));
    });

    test('is nothing for a ride with no length', () {
      final end = now.add(const Duration(minutes: 5));
      final leg = Leg(
        mode: 'BUS',
        from: const TransitPlace(name: 'A', lat: 1, lon: 1),
        to: const TransitPlace(name: 'B', lat: 2, lon: 2),
        startTime: end,
        endTime: end,
        duration: 0,
      );

      expect(remaining(leg), isNull);
    });

    test('is nothing left at the end of the ride', () {
      final leg = ride(arrivesIn: const Duration(minutes: 30));

      expect(remaining(leg, progress: 1), Duration.zero);
    });

    test('once latched, holds when the two come within the margin', () {
      final leg = ride(); // The pace and the timetable agree.

      expect(remaining(leg), isNull);
      expect(remaining(leg, latched: true), const Duration(minutes: 20));
    });

    test('latched still waits for fixes and progress', () {
      final leg = ride();

      expect(remaining(leg, fixes: 3, latched: true), isNull);
      expect(remaining(leg, progress: 0.01, latched: true), isNull);
    });
  });
}
