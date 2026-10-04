import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/services/itinerary_navigation_tracker.dart';
import 'package:transportia/utils/itinerary_leg_utils.dart';

final DateTime _now = DateTime.utc(2026, 9, 28, 8, 30);

/// A 40 minute ride, timetabled to arrive 5 minutes from [_now]: far from
/// where a rider half way along it will find themselves.
Leg _ride() {
  final end = _now.add(const Duration(minutes: 5));
  return Leg(
    mode: 'REGIONAL_RAIL',
    from: const TransitPlace(name: 'A', lat: 1, lon: 1),
    to: const TransitPlace(name: 'B', lat: 2, lon: 2),
    startTime: end.subtract(const Duration(minutes: 40)),
    endTime: end,
    scheduledStartTime: DateTime.utc(2026, 9, 28, 8, 0),
    scheduledEndTime: DateTime.utc(2026, 9, 28, 8, 40),
    duration: const Duration(minutes: 40).inSeconds,
  );
}

Leg _walk() => Leg(
  mode: 'WALK',
  from: const TransitPlace(name: 'B', lat: 2, lon: 2),
  to: const TransitPlace(name: 'C', lat: 2.1, lon: 2.1),
  startTime: _now,
  endTime: _now.add(const Duration(minutes: 5)),
  duration: 300,
  distance: 400,
);

ItineraryNavigationTracker _tracker() => ItineraryNavigationTracker([
  DisplayLegInfo(leg: _ride(), originalIndex: 0),
  DisplayLegInfo(leg: _walk(), originalIndex: 1),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rider\'s own pace', () {
    test('is not given before the fixes and the distance are there', () {
      final tracker = _tracker()
        ..fixesOnLeg = 9
        ..legProgress = 0.5;

      expect(tracker.virtualRemainingNow(now: _now), isNull);
    });

    test('is given once they are, when the timetable is that far out', () {
      final tracker = _tracker()
        ..fixesOnLeg = 10
        ..legProgress = 0.5;

      expect(
        tracker.virtualRemainingNow(now: _now),
        const Duration(minutes: 20),
      );
    });

    test('is nothing for a rider the timetable fits', () {
      final tracker = _tracker()
        ..fixesOnLeg = 10
        ..legProgress = 0.9;

      // 4 minutes left by the pace, 5 by the timetable.
      expect(tracker.virtualRemainingNow(now: _now), isNull);
    });

    test('once given, is kept as the two come back within the margin', () {
      final tracker = _tracker()
        ..fixesOnLeg = 10
        ..legProgress = 0.5;
      expect(tracker.virtualRemainingNow(now: _now), isNotNull);

      // Now 4 minutes by the pace against 5 by the timetable.
      tracker.legProgress = 0.9;

      expect(
        tracker.virtualRemainingNow(now: _now),
        const Duration(minutes: 4),
      );
    });

    test('starts again for the next leg', () {
      final tracker = _tracker()
        ..fixesOnLeg = 10
        ..legProgress = 0.5;
      expect(tracker.virtualRemainingNow(now: _now), isNotNull);

      tracker.start(const LatLng(1, 1), startLegIndex: 0);
      tracker.jumpToLeg(1);
      tracker.jumpToLeg(0);

      expect(tracker.fixesOnLeg, 0);
      // Back on the ride with no fixes yet: nothing is told until they come.
      tracker
        ..legProgress = 0.9
        ..fixesOnLeg = 10;
      expect(tracker.virtualRemainingNow(now: _now), isNull);
      tracker.dispose();
    });

    test('is nothing past the last leg', () {
      final tracker = _tracker()
        ..currentLegIndex = 2
        ..fixesOnLeg = 10
        ..legProgress = 0.5;

      expect(tracker.virtualRemainingNow(now: _now), isNull);
    });
  });
}
