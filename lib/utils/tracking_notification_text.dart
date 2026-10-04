import '../models/itinerary.dart';
import 'itinerary_leg_utils.dart';
import 'itinerary_navigation.dart';
import 'leg_helper.dart';
import 'time_utils.dart';

/// How far along a leg the rider has to be, as a fraction of it, before they
/// are taken to have departed even though the clock says otherwise.
const double _kDepartedProgress = 0.05;

/// How many minutes away a departure or arrival can be before it is given as
/// a countdown rather than as a time of day.
const int _kCountdownWithinMinutes = 15;
const int _kDepartureCountdownWithinMinutes = 20;

/// The notification's title for [leg]: where a walk goes, or the line and
/// the headsign the vehicle shows, which is what lets a rider confirm they
/// are getting on the right one.
String trackingTitle(Leg leg) {
  if (leg.mode == 'WALK') {
    final destination = leg.toName;
    return isPlaceholderEndpointName(destination)
        ? 'Walking to your destination'
        : 'Walking to $destination';
  }
  final routeLabel = _routeLabel(leg);
  final headsign = leg.headsign;
  if (headsign == null || headsign.isEmpty || headsign == routeLabel) {
    return routeLabel;
  }
  return '$routeLabel → $headsign';
}

String _routeLabel(Leg leg) {
  final displayName = leg.displayName;
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final shortName = leg.routeShortName;
  if (shortName != null && shortName.isNotEmpty) return shortName;
  return getTransitModeName(leg.mode);
}

/// A countdown to departure for a transit leg not yet boarded, shown in place
/// of the stops to go. Null for a walk, and once the rider is under way —
/// the departure time has passed, or [legProgress] already shows movement —
/// when the caller falls back to the stop count.
String? waitingLabel(Leg leg, {required double legProgress, DateTime? now}) {
  if (leg.mode == 'WALK') return null;

  final current = now ?? DateTime.now();
  final hasDeparted =
      !current.isBefore(leg.startTime) || legProgress >= _kDepartedProgress;
  if (hasDeparted) return null;

  if (!leg.realTime) {
    return 'Scheduled at ${formatTime(leg.scheduledStartTime ?? leg.startTime)}';
  }

  final remaining = leg.startTime.difference(current);
  if (remaining.inMinutes >= _kDepartureCountdownWithinMinutes) {
    return '🟢 Departs at ${formatTime(leg.startTime)}';
  }
  final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
  return '🟢 Departs in $minutes min';
}

/// "3 stops until X (12:40)", "3 stops, 9 min until X", "X is next, in 4 min"
/// or "X is next, at 12:40". Richer than [progressLabel], which only counts
/// stops and serves the in-app carousel as well: the notification has the leg
/// on hand, so it can name where the rider is getting off and say when they
/// will be there.
String stopsProgressLine(Leg leg, int remainingStops, {DateTime? now}) {
  if (remainingStops <= 0) return 'Arriving now';

  final stopName = leg.toName;
  final arrival = leg.endTime;
  final remaining = arrival.difference(now ?? DateTime.now());
  final isSoon = remaining.inMinutes < _kCountdownWithinMinutes;
  final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;

  if (remainingStops == 1) {
    return isSoon
        ? '$stopName is next, in $minutes min'
        : '$stopName is next, at ${formatTime(arrival)}';
  }

  return isSoon
      ? '$remainingStops stops, $minutes min until $stopName'
      : '$remainingStops stops until $stopName (${formatTime(arrival)})';
}

/// The notification's second line: a countdown while waiting to board, the
/// stops to go on a ride, the distance left on a walk.
String trackingProgressLine(
  Leg? leg, {
  required double legProgress,
  required double? remainingWalkMeters,
  required int? remainingStops,
  DateTime? now,
}) {
  if (leg != null) {
    final waiting = waitingLabel(leg, legProgress: legProgress, now: now);
    if (waiting != null) return waiting;
    if (leg.mode != 'WALK' && remainingStops != null) {
      return stopsProgressLine(leg, remainingStops, now: now);
    }
  }
  return progressLabel(
        remainingWalkMeters: remainingWalkMeters,
        remainingStops: remainingStops,
      ) ??
      '';
}
