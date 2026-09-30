import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../utils/journey_colors.dart';
import '../utils/reported_time.dart';
import '../utils/time_utils.dart';

/// A time at a stop, printed the way the journey spine prints it: the real
/// time, coloured by who is reporting it, and the delay right beneath it in
/// grey.
///
/// Every list of times goes through this, so no screen can go back to
/// printing the plan with a "+5m" for the rider to add up. The delay is a
/// line of its own in the layout rather than something drawn over it, so
/// whatever holds a delayed time grows to fit it.
class DelayedTime extends StatelessWidget {
  /// The delay under the time's first digit — for times read left to right.
  const DelayedTime.start(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _alignment = CrossAxisAlignment.start;

  /// The delay under the time's last digit — for a column of times against
  /// the end of a row.
  const DelayedTime.end(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _alignment = CrossAxisAlignment.end;

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
  final CrossAxisAlignment _alignment;

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
    final delay = _delay();
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _alignment,
      children: [_clock(), ?delay],
    );
    final label = this.label;
    if (label == null) return column;
    // Beside the column rather than in it, so the delay lines up under the
    // time it belongs to, not under the word naming it.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$label ',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
        column,
      ],
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
    return Text(
      time == null ? _placeholder : formatTime(time.shown),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: timeColor,
      ),
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
