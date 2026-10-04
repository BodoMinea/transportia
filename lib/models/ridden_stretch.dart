import 'itinerary.dart';

/// The part of a whole trip that a rider's journey uses, for showing a trip
/// from inside a journey: the stops and the line before and after it are
/// there to see, but are not the ones being ridden.
class RiddenStretch {
  const RiddenStretch({required this.from, required this.to});

  /// The stretch of [leg], from where it boards to where it alights.
  RiddenStretch.ofLeg(Leg leg) : this(from: leg.from, to: leg.to);

  final TransitPlace from;
  final TransitPlace to;

  /// The indices into [trip]'s [Leg.stopSequence] of the two ends of the
  /// stretch, or null when there is nothing to tell apart: [trip] does not
  /// call at both, or the stretch is all of it.
  ///
  /// A stretch that cannot be found is left undrawn rather than guessed at;
  /// lightening the wrong part of a line would say something false.
  ({int start, int end})? rangeOn(Leg trip) {
    final range = trip.stopRangeBetween(from, to);
    if (range == null) return null;
    final isWholeTrip =
        range.start == 0 && range.end == trip.stopSequence.length - 1;
    return isWholeTrip ? null : range;
  }
}
