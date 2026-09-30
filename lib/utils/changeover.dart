import '../models/itinerary.dart';
import 'itinerary_leg_utils.dart';
import 'journey_colors.dart' show isStreetLeg;

/// How long before the search a replanned journey should leave.
///
/// A search departing this second answers with trains you are already running
/// for. Ten minutes is room to read the screen and walk.
const Duration kReplanHeadStart = Duration(minutes: 10);

/// One change between two services, seen from both sides.
///
/// A walk carries no real-time of its own, so whether a change still works can
/// only be answered by the ride arriving and the ride leaving. This holds that
/// pair, and only that.
class Changeover {
  const Changeover({required this.transfer, this.arriving, this.departing});

  /// The ride that gets you here. Null when the journey starts on this walk.
  final Leg? arriving;

  /// The walk across, which is what makes this a change rather than a stop.
  final Leg transfer;

  /// The ride that leaves. Null when the journey ends on this walk.
  final Leg? departing;

  /// The stop the change happens at.
  TransitPlace get place => transfer.from;

  String get placeName => transfer.fromName;

  /// When you really get here — the operator's figure where there is one.
  ///
  /// The transfer leg's own `from` place carries the arriving service's
  /// real-time; the walk's `startTime` does not. Where the feed leaves the
  /// place empty the arriving leg's own end is the next best thing.
  DateTime? get arrivesAt =>
      transfer.from.arrival ?? arriving?.endTime ?? transfer.startTime;

  /// When the onward service really leaves.
  DateTime? get departsAt =>
      departing?.from.departure ?? departing?.startTime ?? transfer.endTime;

  /// What you have between getting here and it leaving.
  Duration? get gap {
    final from = arrivesAt;
    final to = departsAt;
    if (from == null || to == null) return null;
    return to.difference(from);
  }

  /// What the change costs you: the walk itself.
  Duration get needs => Duration(seconds: transfer.duration);

  /// True when an operator is reporting one of the two services, so the
  /// numbers above are observations rather than a timetable.
  bool get isLive =>
      (arriving?.realTime ?? false) || (departing?.realTime ?? false);

  /// The change cannot be made: the onward service leaves before you can walk
  /// to it.
  ///
  /// Gated on [isLive] deliberately. A planner never builds a change it cannot
  /// make, so a negative gap can only come from real-time — and judging a
  /// purely scheduled itinerary would invent a problem, making every saved
  /// trip opened offline shout about a connection that is fine.
  bool get isMissed {
    if (!isLive) return false;
    if (arriving == null || departing == null) return false;
    final gap = this.gap;
    return gap != null && gap < needs;
  }

  /// The change is at a mainline station and a train on one side of it has
  /// no platform there, so the walk between them was routed to a guess.
  ///
  /// At a small stop the walk is short whatever the platforms. At a station
  /// a regional or longer train calls at it can be most of the change, and
  /// without both ends the planner's route and time for it are an estimate.
  /// Only trains are asked for a platform: a tram or bus on the other side
  /// usually has none in the feed, and not knowing it is no news.
  bool get platformUnknown {
    final sides = [
      if (arriving case final ride?) (ride, _arrivalPlatform),
      if (departing case final ride?) (ride, _departurePlatform),
    ];
    final atMainlineStation = sides.any(
      (side) => _modeOf(side.$1)?.isRegionalOrLongerRail ?? false,
    );
    if (!atMainlineStation) return false;
    return sides.any(
      (side) => (_modeOf(side.$1)?.isTrain ?? false) && side.$2 == null,
    );
  }

  /// Where the arriving train stops. The walk starts from the same place, so
  /// its platform stands in where the train's own is missing.
  String? get _arrivalPlatform => _firstPlatform([
    arriving?.to.track,
    arriving?.to.scheduledTrack,
    transfer.from.track,
    transfer.from.scheduledTrack,
  ]);

  /// Where the departing train leaves from, or failing that where the walk
  /// ends.
  String? get _departurePlatform => _firstPlatform([
    departing?.from.track,
    departing?.from.scheduledTrack,
    transfer.to.track,
    transfer.to.scheduledTrack,
  ]);

  static String? _firstPlatform(List<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static TransitMode? _modeOf(Leg leg) => TransitMode.fromWire(leg.mode);
}

/// Every change in a journey, in the order they are travelled.
///
/// Reads [buildDisplayLegs]' own verdict on what counts as a change — any
/// street leg with a ride on either side — so the warning and the row it
/// points at can never disagree about which legs those are.
List<Changeover> changeoversOf(List<DisplayLegInfo> displayLegs) {
  final changes = <Changeover>[];
  for (var i = 0; i < displayLegs.length; i++) {
    final entry = displayLegs[i];
    if (!entry.isTransfer) continue;
    changes.add(
      Changeover(
        transfer: entry.leg,
        arriving: i > 0 ? displayLegs[i - 1].leg : null,
        departing: i + 1 < displayLegs.length ? displayLegs[i + 1].leg : null,
      ),
    );
  }
  return changes;
}

/// A search to hand the routing screen: where from, where to, and when.
class Replan {
  const Replan({required this.from, required this.to, required this.departAt});

  final TransitPlace from;
  final TransitPlace to;
  final DateTime departAt;
}

/// The journey to offer when this one breaks.
///
/// Where you leave from is not the change that broke: by the time it breaks
/// you may be past it, or not yet aboard. Before the journey has started it is
/// the origin — the whole journey again, because a different first train is
/// still open to you. Once under way it is the first place the itinerary
/// reaches at or after [now], which is the next point at which you can
/// actually act; you cannot get off between stations.
///
/// The time is the later of [now] plus [kReplanHeadStart] and the moment you
/// reach that place. The head start is breathing room; the second term is what
/// keeps the answer usable, since a search leaving a station long before you
/// get there returns services you cannot board.
Replan? replanFor(List<Leg> legs, DateTime now) {
  if (legs.isEmpty) return null;

  final origin = legs.first.from;
  final destination = legs.last.to;
  final earliest = now.add(kReplanHeadStart);
  final wholeJourney = Replan(
    from: origin,
    to: destination,
    departAt: earliest,
  );

  final start = origin.departure ?? legs.first.startTime;
  if (!now.isAfter(start)) return wholeJourney;

  for (final leg in legs) {
    // A street leg ends on a doorstep or on the platform you are walking to,
    // neither of which a search can leave from. The ride names the stop.
    if (isStreetLeg(leg.mode)) continue;
    final arrival = leg.to.arrival ?? leg.endTime;
    if (arrival.isBefore(now)) continue;
    return Replan(
      from: leg.to,
      to: destination,
      departAt: arrival.isAfter(earliest) ? arrival : earliest,
    );
  }

  // Every stop is behind you, so there is nothing ahead to leave from.
  return wholeJourney;
}
