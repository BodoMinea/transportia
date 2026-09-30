import 'time_utils.dart';

/// One printable time at a stop: the one to read, and how far it is from the
/// plan.
///
/// [shown] is what the rider reads: the real time when the operator is
/// reporting one, the timetable's otherwise. The planned time is never
/// printed alongside it — a rider wants the time the train is at the
/// platform, not two numbers and a subtraction.
class ReportedTime {
  final DateTime shown;
  final Duration? delay;

  /// True when the operator is actually reporting this service, so [shown] is
  /// an observation rather than a promise. Drives the colour.
  ///
  /// It comes from the service's own `realTime` flag rather than from a time
  /// merely existing — the planner always fills a start and an end in, so
  /// "we have a number" says nothing about where the number came from.
  final bool isLive;

  const ReportedTime({
    required this.shown,
    required this.delay,
    required this.isLive,
  });

  /// Null when the feed gave neither a real-time nor a scheduled value.
  static ReportedTime? from(
    DateTime? actual,
    DateTime? scheduled, {
    required bool isLive,
  }) {
    if (actual == null && scheduled == null) return null;
    // Real-time wins outright. Where only one exists it is both the promise
    // and the fact, so there is nothing to be late against.
    final shown = actual ?? scheduled!;
    final delay = (actual != null && scheduled != null)
        ? computeDelay(scheduled, actual)
        : null;
    return ReportedTime(shown: shown, delay: delay, isLive: isLive);
  }
}
