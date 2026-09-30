import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../utils/journey_colors.dart';
import '../utils/reported_time.dart';
import '../utils/time_utils.dart';

enum _DelayPlacement { underStart, underEnd, after }

/// A time at a stop, printed the way the journey spine prints it: the real
/// time, coloured by who is reporting it, and the delay in grey — under it,
/// or after it where a column of labelled times would otherwise lose its
/// left edge.
///
/// Every list of times goes through this, so no screen can go back to
/// printing the plan with a "+5m" for the rider to add up. The delay is laid
/// out, never drawn over anything, so whatever holds a delayed time grows to
/// fit it.
class DelayedTime extends StatelessWidget {
  /// The delay under the time's first digit — for times read left to right.
  const DelayedTime.start(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _placement = _DelayPlacement.underStart;

  /// The delay under the time's last digit — for a column of times against
  /// the end of a row.
  const DelayedTime.end(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _placement = _DelayPlacement.underEnd;

  /// The delay after the time, on the same line — for a stack of labelled
  /// times ("Arr", "Dep"), where a delay under the time would sit out of line
  /// with the labels around it. It drops to the next line only when the line
  /// has no room.
  const DelayedTime.inline(
    this.time, {
    super.key,
    this.label,
    this.isArrival = false,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  }) : _placement = _DelayPlacement.after;

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
  final _DelayPlacement _placement;

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
    final label = this.label == null ? null : _label(this.label!);
    if (_placement == _DelayPlacement.after) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          ?label,
          _clock(),
          if (delay != null)
            Padding(padding: const EdgeInsets.only(left: 6), child: delay),
        ],
      );
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _placement == _DelayPlacement.underEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [_clock(), ?delay],
    );
    if (label == null) return column;
    // Beside the column rather than in it, so the delay lines up under the
    // time it belongs to, not under the word naming it.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [label, column],
    );
  }

  Widget _label(String label) => Text(
    '$label ',
    maxLines: 1,
    softWrap: false,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: AppColors.black.withValues(alpha: 0.6),
    ),
  );

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
