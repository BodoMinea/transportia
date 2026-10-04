import '../models/saved_trip.dart';
import 'journey_colors.dart' show isStreetLeg;

/// When in the day a trip leaves.
enum DayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening'),
  night('Night');

  const DayPart(this.label);

  final String label;

  /// The part of the day [hour] (0–23, local time) falls in.
  static DayPart ofHour(int hour) {
    if (hour < 6) return DayPart.night;
    if (hour < 12) return DayPart.morning;
    if (hour < 18) return DayPart.afternoon;
    return DayPart.evening;
  }
}

/// What the saved trips add up to.
///
/// Only trips the rider chose to keep are counted, and only the ones already
/// over say anything about how they travel; the ones still ahead are counted
/// and left at that. It is a partial picture by construction, not a travel
/// log.
class TripStats {
  const TripStats({
    required this.pastCount,
    required this.upcomingCount,
    required this.walkingTime,
    required this.transitTime,
    required this.timeByMode,
    required this.tripsByDayPart,
    required this.topOrigin,
    required this.topDestination,
  });

  final int pastCount;
  final int upcomingCount;

  /// Time on foot, and time on services, over the past trips. Cycling,
  /// driving and the like are neither, and appear only in [timeByMode].
  final Duration walkingTime;
  final Duration transitTime;

  /// Time per leg mode (as the API names it), longest first.
  final List<MapEntry<String, Duration>> timeByMode;

  /// Past trips per part of the day, in the order of the day; parts with none
  /// are left out.
  final List<MapEntry<DayPart, int>> tripsByDayPart;

  /// Where past trips most often start and end, or null with no past trips.
  /// A tie goes to whichever place was seen first.
  final String? topOrigin;
  final String? topDestination;

  Duration get totalModeTime =>
      timeByMode.fold(Duration.zero, (sum, entry) => sum + entry.value);

  /// [trips] as of [now], which decides what is past.
  static TripStats compute(List<SavedTrip> trips, {required DateTime now}) {
    final past = [
      for (final trip in trips)
        if (trip.arrivalTime.isBefore(now)) trip,
    ];

    var walking = Duration.zero;
    var transit = Duration.zero;
    final byMode = <String, Duration>{};
    final byDayPart = <DayPart, int>{};
    final origins = <String, int>{};
    final destinations = <String, int>{};

    for (final trip in past) {
      for (final leg in trip.itinerary.legs) {
        final duration = Duration(seconds: leg.duration);
        if (leg.mode == 'WALK') {
          walking += duration;
        } else if (!isStreetLeg(leg.mode)) {
          transit += duration;
        }
        byMode.update(leg.mode, (v) => v + duration, ifAbsent: () => duration);
      }
      byDayPart.update(
        DayPart.ofHour(trip.departureTime.toLocal().hour),
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      origins.update(trip.fromName, (v) => v + 1, ifAbsent: () => 1);
      destinations.update(trip.toName, (v) => v + 1, ifAbsent: () => 1);
    }

    return TripStats(
      pastCount: past.length,
      upcomingCount: trips.length - past.length,
      walkingTime: walking,
      transitTime: transit,
      timeByMode: byMode.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
      tripsByDayPart: [
        for (final part in DayPart.values)
          if (byDayPart[part] case final count?) MapEntry(part, count),
      ],
      topOrigin: _mostCommon(origins),
      topDestination: _mostCommon(destinations),
    );
  }

  static String? _mostCommon(Map<String, int> counts) {
    String? best;
    var bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }
}
