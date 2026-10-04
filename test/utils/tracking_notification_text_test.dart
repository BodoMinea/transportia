import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/time_utils.dart';
import 'package:transportia/utils/tracking_notification_text.dart';

final DateTime _now = DateTime.utc(2026, 9, 28, 8);

Leg _ride({
  String? displayName = 'RE7',
  String? headsign = 'Flughafen BER',
  bool realTime = true,
  Duration departsIn = const Duration(minutes: 30),
  Duration rides = const Duration(minutes: 40),
  DateTime? scheduledStart,
}) => Leg(
  mode: 'REGIONAL_RAIL',
  from: const TransitPlace(name: 'Hauptbahnhof', lat: 52.5, lon: 13.3),
  to: const TransitPlace(name: 'Flughafen BER', lat: 52.3, lon: 13.5),
  startTime: _now.add(departsIn),
  endTime: _now.add(departsIn + rides),
  scheduledStartTime: scheduledStart,
  duration: rides.inSeconds,
  realTime: realTime,
  displayName: displayName,
  headsign: headsign,
);

Leg _walk({String to = 'Hauptbahnhof'}) => Leg(
  mode: 'WALK',
  from: const TransitPlace(name: 'START', lat: 52.5, lon: 13.3),
  to: TransitPlace(name: to, lat: 52.5, lon: 13.4),
  startTime: _now,
  endTime: _now.add(const Duration(minutes: 5)),
  duration: 300,
  distance: 420,
);

void main() {
  group('the title', () {
    test('is the line and the headsign the vehicle shows', () {
      expect(trackingTitle(_ride()), 'RE7 → Flughafen BER');
    });

    test('is just the line when the headsign adds nothing', () {
      expect(trackingTitle(_ride(headsign: 'RE7')), 'RE7');
      expect(trackingTitle(_ride(headsign: null)), 'RE7');
      expect(trackingTitle(_ride(headsign: '')), 'RE7');
    });

    test('falls back to the short name, then to the mode', () {
      expect(trackingTitle(_ride(displayName: null, headsign: null)), 'Train');
    });

    test('says where a walk goes', () {
      expect(trackingTitle(_walk()), 'Walking to Hauptbahnhof');
    });

    test('does not announce a walk to END', () {
      expect(trackingTitle(_walk(to: 'END')), 'Walking to your destination');
      expect(trackingTitle(_walk(to: '')), 'Walking to your destination');
    });
  });

  group('waiting to board', () {
    test('a live departure a way off is a time', () {
      final label = waitingLabel(_ride(), legProgress: 0, now: _now);

      expect(
        label,
        '🟢 Departs at ${formatTime(_now.add(const Duration(minutes: 30)))}',
      );
    });

    test('a live departure soon is a countdown', () {
      final label = waitingLabel(
        _ride(departsIn: const Duration(minutes: 7, seconds: 30)),
        legProgress: 0,
        now: _now,
      );

      expect(label, '🟢 Departs in 7 min');
    });

    test('is never less than a minute', () {
      final label = waitingLabel(
        _ride(departsIn: const Duration(seconds: 20)),
        legProgress: 0,
        now: _now,
      );

      expect(label, '🟢 Departs in 1 min');
    });

    test('a departure with no live data says it is the timetable', () {
      final label = waitingLabel(
        _ride(
          realTime: false,
          scheduledStart: _now.add(const Duration(minutes: 28)),
        ),
        legProgress: 0,
        now: _now,
      );

      expect(
        label,
        'Scheduled at ${formatTime(_now.add(const Duration(minutes: 28)))}',
      );
    });

    test('nothing once the departure has passed', () {
      expect(
        waitingLabel(
          _ride(departsIn: Duration.zero),
          legProgress: 0,
          now: _now,
        ),
        isNull,
      );
    });

    test('nothing once the rider has visibly started moving', () {
      expect(waitingLabel(_ride(), legProgress: 0.2, now: _now), isNull);
    });

    test('nothing for a walk', () {
      expect(waitingLabel(_walk(), legProgress: 0, now: _now), isNull);
    });
  });

  group('stops to go', () {
    final leg = _ride(departsIn: Duration.zero);

    test('arriving now with none left', () {
      expect(stopsProgressLine(leg, 0, now: _now), 'Arriving now');
    });

    test('several stops from a way off give the time of arrival', () {
      expect(
        stopsProgressLine(leg, 4, now: _now),
        '4 stops until Flughafen BER (${formatTime(leg.endTime)})',
      );
    });

    test('several stops from close give the minutes', () {
      final soon = _ride(
        departsIn: Duration.zero,
        rides: const Duration(minutes: 9),
      );

      expect(
        stopsProgressLine(soon, 4, now: _now),
        '4 stops, 9 min until Flughafen BER',
      );
    });

    test('the next stop is named, with when', () {
      expect(
        stopsProgressLine(leg, 1, now: _now),
        'Flughafen BER is next, at ${formatTime(leg.endTime)}',
      );
      final soon = _ride(
        departsIn: Duration.zero,
        rides: const Duration(minutes: 3),
      );
      expect(
        stopsProgressLine(soon, 1, now: _now),
        'Flughafen BER is next, in 3 min',
      );
    });
  });

  group('stops to go at the rider\'s own pace', () {
    final leg = _ride(departsIn: Duration.zero);

    test('several stops give an estimate in minutes, never a time of day', () {
      final line = stopsProgressLine(
        leg,
        4,
        now: _now,
        virtualRemaining: const Duration(minutes: 22),
      );

      expect(line, '4 stops, ~22 min until Flughafen BER');
      expect(line, isNot(contains(formatTime(leg.endTime))));
      expect(line, isNot(contains(':')));
    });

    test('says it is an estimate even when it is a long way off', () {
      // The timetable's wording would switch to a time of day here.
      expect(
        stopsProgressLine(
          leg,
          9,
          now: _now,
          virtualRemaining: const Duration(minutes: 55),
        ),
        '9 stops, ~55 min until Flughafen BER',
      );
    });

    test('the next stop is named, with an estimate', () {
      expect(
        stopsProgressLine(
          leg,
          1,
          now: _now,
          virtualRemaining: const Duration(minutes: 4),
        ),
        'Flughafen BER is next, in ~4 min',
      );
    });

    test('rounds to the nearest minute, and never says less than one', () {
      expect(estimatedMinutes(const Duration(seconds: 89)), 1);
      expect(estimatedMinutes(const Duration(seconds: 90)), 2);
      expect(estimatedMinutes(const Duration(minutes: 7, seconds: 20)), 7);
      expect(estimatedMinutes(const Duration(seconds: 10)), 1);
      expect(estimatedMinutes(Duration.zero), 1);
    });

    test('arriving now stays as it is', () {
      expect(
        stopsProgressLine(
          leg,
          0,
          now: _now,
          virtualRemaining: const Duration(minutes: 3),
        ),
        'Arriving now',
      );
    });

    test('without an estimate the timetable is used, as before', () {
      expect(
        stopsProgressLine(leg, 4, now: _now),
        '4 stops until Flughafen BER (${formatTime(leg.endTime)})',
      );
    });

    test('the progress line carries it through', () {
      expect(
        trackingProgressLine(
          leg,
          legProgress: 0.4,
          remainingWalkMeters: null,
          remainingStops: 4,
          now: _now,
          virtualRemaining: const Duration(minutes: 22),
        ),
        '4 stops, ~22 min until Flughafen BER',
      );
    });

    test('a ride not yet boarded still counts down to boarding', () {
      final waiting = _ride(departsIn: const Duration(minutes: 5));

      expect(
        trackingProgressLine(
          waiting,
          legProgress: 0,
          remainingWalkMeters: null,
          remainingStops: 4,
          now: _now,
          virtualRemaining: const Duration(minutes: 22),
        ),
        '🟢 Departs in 5 min',
      );
    });

    test('a walk is not given one', () {
      expect(
        trackingProgressLine(
          _walk(),
          legProgress: 0.5,
          remainingWalkMeters: 210,
          remainingStops: null,
          now: _now,
          virtualRemaining: const Duration(minutes: 22),
        ),
        '210 m to go',
      );
    });
  });

  group('the progress line', () {
    test('waits to board when that is what is happening', () {
      expect(
        trackingProgressLine(
          _ride(departsIn: const Duration(minutes: 5)),
          legProgress: 0,
          remainingWalkMeters: null,
          remainingStops: 6,
          now: _now,
        ),
        '🟢 Departs in 5 min',
      );
    });

    test('counts the stops once under way', () {
      expect(
        trackingProgressLine(
          _ride(departsIn: Duration.zero),
          legProgress: 0.3,
          remainingWalkMeters: null,
          remainingStops: 6,
          now: _now,
        ),
        startsWith('6 stops'),
      );
    });

    test('gives the distance left on a walk', () {
      expect(
        trackingProgressLine(
          _walk(),
          legProgress: 0.5,
          remainingWalkMeters: 210,
          remainingStops: null,
          now: _now,
        ),
        '210 m to go',
      );
    });

    test('is empty with nothing to say', () {
      expect(
        trackingProgressLine(
          null,
          legProgress: 0,
          remainingWalkMeters: null,
          remainingStops: null,
        ),
        isEmpty,
      );
    });
  });
}
