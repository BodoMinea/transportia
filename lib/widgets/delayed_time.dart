import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../utils/journey_colors.dart';
import '../utils/reported_time.dart';
import '../utils/time_utils.dart';

/// A time at a stop, printed the way the journey spine prints it: the real
/// time, coloured by who is reporting it, and the delay beside it in grey.
///
/// Every list of times goes through this, so no screen can go back to
/// printing the plan with a "+5m" for the rider to add up.
class DelayedTime extends StatelessWidget {
  /// The delay on the same line, after the time.
  const DelayedTime.inline(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _stacked = false;

  /// The delay on its own line under the time, both aligned to the end — for
  /// a column of times at the end of a row.
  const DelayedTime.stacked(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _stacked = true;

  /// Null prints a placeholder, so a row of arrivals and departures keeps its
  /// shape where the feed has no time for one of them.
  final ReportedTime? time;

  /// A word before the time, such as "Arr", in the text colour: it names the
  /// time rather than reporting on it.
  final String? label;

  /// The lighter shade the spine gives an arrival shown beside its departure.
  /// A time standing alone takes the strong one whichever it is.
  final bool isArrival;

  final double fontSize;
  final FontWeight fontWeight;
  final bool _stacked;

  static const String _placeholder = '--:--';

  /// Smaller than the time, never so small it stops being legible.
  static const double _delayScale = 0.8;
  static const double _minDelaySize = 11.5;

  double get _delaySize {
    final scaled = fontSize * _delayScale;
    return scaled < _minDelaySize ? _minDelaySize : scaled;
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock();
    final delay = _delay();
    if (delay == null) return clock;
    if (_stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [clock, delay],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [clock, const SizedBox(width: 6), delay],
    );
  }

  Widget _clock() {
    final time = this.time;
    final timeColor = time == null
        ? AppColors.black.withValues(alpha: 0.6)
        : spineTimeColor(
            isLive: time.isLive,
            delay: time.delay,
            isArrival: isArrival,
          );
    return Text.rich(
      TextSpan(
        children: [
          if (label case final label?)
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          TextSpan(
            text: time == null ? _placeholder : formatTime(time.shown),
            style: TextStyle(color: timeColor),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
    );
  }

  Widget? _delay() {
    final delay = time?.delay;
    if (delay == null) return null;
    return Text(
      formatDelay(delay),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: _delaySize,
        fontWeight: FontWeight.w600,
        color: delayNoteColor(),
      ),
    );
  }
}
