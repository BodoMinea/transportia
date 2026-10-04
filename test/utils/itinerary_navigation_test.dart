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
}
