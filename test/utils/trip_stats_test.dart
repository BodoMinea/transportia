import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/utils/trip_stats.dart';

import '../support/plan_fixtures.dart';

final DateTime _now = DateTime.utc(2026, 9, 28, 12);

/// A saved trip leaving [hoursFromNow] from [_now]: 5 minutes on foot, a
/// [ride] on the train, 3 minutes on foot.
SavedTrip _trip({
  required int hoursFromNow,
  String from = 'Home',
  String to = 'Airport',
  Duration ride = const Duration(minutes: 15),
  String id = 'trip',
}) => SavedTrip.fromItinerary(
  itinerary: Itinerary.fromJson(
    planItineraryJson(
      departure: _now.add(Duration(hours: hoursFromNow)),
      rideLength: ride,
      tripId: '$id-$hoursFromNow',
    ),
  ),
  fromName: from,
  toName: to,
);

void main() {
  group('with nothing saved', () {
    test('everything is zero or absent', () {
      final stats = TripStats.compute(const [], now: _now);

      expect(stats.pastCount, 0);
      expect(stats.upcomingCount, 0);
      expect(stats.walkingTime, Duration.zero);
      expect(stats.transitTime, Duration.zero);
      expect(stats.timeByMode, isEmpty);
      expect(stats.tripsByDayPart, isEmpty);
      expect(stats.topOrigin, isNull);
      expect(stats.topDestination, isNull);
    });
  });

  group('past and upcoming', () {
    test('a trip is past once it has arrived', () {
      final stats = TripStats.compute([
        _trip(hoursFromNow: -5),
        _trip(hoursFromNow: -1),
        _trip(hoursFromNow: 3),
      ], now: _now);

      expect(stats.pastCount, 2);
      expect(stats.upcomingCount, 1);
    });

    test('a trip still under way is not past', () {
      // Left five minutes ago on a 23-minute journey.
      final underWay = SavedTrip.fromItinerary(
        itinerary: Itinerary.fromJson(
          planItineraryJson(
            departure: _now.subtract(const Duration(minutes: 5)),
          ),
        ),
      );

      expect(TripStats.compute([underWay], now: _now).pastCount, 0);
    });

    test('upcoming trips add nothing to the totals', () {
      final stats = TripStats.compute([_trip(hoursFromNow: 4)], now: _now);

      expect(stats.walkingTime, Duration.zero);
      expect(stats.timeByMode, isEmpty);
      expect(stats.topOrigin, isNull);
    });
  });

  group('time spent', () {
    test('walking and riding are told apart', () {
      final stats = TripStats.compute([_trip(hoursFromNow: -5)], now: _now);

      expect(stats.walkingTime, const Duration(minutes: 8));
      expect(stats.transitTime, const Duration(minutes: 15));
    });

    test('they add up over trips', () {
      final stats = TripStats.compute([
        _trip(hoursFromNow: -5),
        _trip(hoursFromNow: -9, ride: const Duration(minutes: 30)),
      ], now: _now);

      expect(stats.walkingTime, const Duration(minutes: 16));
      expect(stats.transitTime, const Duration(minutes: 45));
    });

    test('the mode share lists the longest first, walking included', () {
      final stats = TripStats.compute([_trip(hoursFromNow: -5)], now: _now);

      expect(stats.timeByMode.map((e) => e.key), ['REGIONAL_RAIL', 'WALK']);
      expect(stats.totalModeTime, const Duration(minutes: 23));
    });
  });

  group('time of day', () {
    test('the hours fall into their parts of the day', () {
      expect(DayPart.ofHour(0), DayPart.night);
      expect(DayPart.ofHour(5), DayPart.night);
      expect(DayPart.ofHour(6), DayPart.morning);
      expect(DayPart.ofHour(11), DayPart.morning);
      expect(DayPart.ofHour(12), DayPart.afternoon);
      expect(DayPart.ofHour(17), DayPart.afternoon);
      expect(DayPart.ofHour(18), DayPart.evening);
      expect(DayPart.ofHour(23), DayPart.evening);
    });

    test('trips are counted in the order of the day, empty parts left out', () {
      // Departures are read in local time, so build them there.
      SavedTrip at(int hour, String id) => SavedTrip.fromItinerary(
        itinerary: Itinerary.fromJson(
          planItineraryJson(
            departure: DateTime(2026, 9, 27, hour).toUtc(),
            tripId: id,
          ),
        ),
      );

      final stats = TripStats.compute([
        at(20, 'a'),
        at(8, 'b'),
        at(9, 'c'),
      ], now: _now);

      expect(stats.tripsByDayPart.map((e) => e.key), [
        DayPart.morning,
        DayPart.evening,
      ]);
      expect(stats.tripsByDayPart.map((e) => e.value), [2, 1]);
    });
  });

  group('top places', () {
    test('the most common start and end win', () {
      final stats = TripStats.compute([
        _trip(hoursFromNow: -2, from: 'Home', to: 'Work', id: 'a'),
        _trip(hoursFromNow: -4, from: 'Home', to: 'Gym', id: 'b'),
        _trip(hoursFromNow: -6, from: 'Work', to: 'Gym', id: 'c'),
      ], now: _now);

      expect(stats.topOrigin, 'Home');
      expect(stats.topDestination, 'Gym');
    });

    test('a tie goes to the place seen first', () {
      final stats = TripStats.compute([
        _trip(hoursFromNow: -2, from: 'Home', to: 'Work', id: 'a'),
        _trip(hoursFromNow: -4, from: 'Gym', to: 'Cafe', id: 'b'),
      ], now: _now);

      expect(stats.topOrigin, 'Home');
      expect(stats.topDestination, 'Work');
    });
  });
}
