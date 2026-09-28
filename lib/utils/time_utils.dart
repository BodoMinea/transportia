import 'package:flutter/widgets.dart';

String formatTime(DateTime? dateTime, {String nullPlaceholder = '-'}) {
  if (dateTime == null) return nullPlaceholder;

  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Whether [a] and [b] fall in the same local wall-clock minute.
bool isSameMinute(DateTime a, DateTime b) {
  final aLocal = a.toLocal();
  final bLocal = b.toLocal();
  return aLocal.year == bLocal.year &&
      aLocal.month == bLocal.month &&
      aLocal.day == bLocal.day &&
      aLocal.hour == bLocal.hour &&
      aLocal.minute == bLocal.minute;
}

Duration? computeDelay(
  DateTime? scheduledTime,
  DateTime actualTime, {
  Duration threshold = const Duration(minutes: 1),
}) {
  if (scheduledTime == null) return null;
  final diff = actualTime.difference(scheduledTime);
  if (diff.inSeconds.abs() < threshold.inSeconds) return null;
  return diff;
}

String formatDelay(Duration delay) {
  final isNegative = delay.isNegative;
  final totalMinutes = delay.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final buffer = <String>[];
  if (hours > 0) buffer.add('${hours}h');
  if (minutes > 0 || buffer.isEmpty) buffer.add('${minutes}m');
  final sign = isNegative ? '-' : '+';
  return '$sign${buffer.join(' ')}';
}

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Day label for a date the user is looking at in relation to now:
/// 'Today', 'Tomorrow', a weekday name within the coming week, or a
/// short date beyond that.
String formatRelativeDay(DateTime dateTime, {DateTime? now}) {
  final local = dateTime.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();

  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  final dayDifference = day.difference(today).inDays;

  if (dayDifference == 0) return 'Today';
  if (dayDifference == 1) return 'Tomorrow';
  if (dayDifference == -1) return 'Yesterday';
  if (dayDifference > 1 && dayDifference < 7) return formatWeekday(local);
  return formatDayMonth(local);
}

/// Short weekday name, e.g. 'Thu'.
String formatWeekday(DateTime dateTime) => _weekdayNames[dateTime.weekday - 1];

/// Day of month and short month name, e.g. '25 Sep'.
String formatDayMonth(DateTime dateTime) =>
    '${dateTime.day} ${_monthNames[dateTime.month - 1]}';

/// Month name and year, e.g. 'September 2026'.
String formatMonthYear(DateTime dateTime) =>
    '${_fullMonthNames[dateTime.month - 1]} ${dateTime.year}';

/// The month holding [month] laid out as calendar rows, Monday first: whole
/// weeks of seven, with null for the cells before the 1st and after the last
/// day.
List<DateTime?> monthGrid(DateTime month) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
  final cellCount =
      ((leadingBlanks + daysInMonth + DateTime.daysPerWeek - 1) ~/
          DateTime.daysPerWeek) *
      DateTime.daysPerWeek;
  return [
    for (var cell = 0; cell < cellCount; cell++)
      cell < leadingBlanks || cell >= leadingBlanks + daysInMonth
          ? null
          : DateTime(month.year, month.month, cell - leadingBlanks + 1),
  ];
}

/// Local midnight of each calendar day from [first] to [last], both included;
/// empty when [last] is before [first].
///
/// Steps by calendar day rather than by 24 hours, so a daylight-saving switch
/// neither skips nor repeats a day.
List<DateTime> calendarDays(DateTime first, DateTime last) {
  final end = DateTime(last.year, last.month, last.day);
  return [
    for (
      var day = DateTime(first.year, first.month, first.day);
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      day,
  ];
}

String formatIso8601Millis(DateTime dateTime) {
  final utc = dateTime.toUtc();
  final base = utc.toIso8601String();
  final dot = base.indexOf('.');
  if (dot == -1) {
    return base;
  }
  final millis = utc.millisecond.toString().padLeft(3, '0');
  return '${base.substring(0, dot)}.${millis}Z';
}

Color delayColor(Duration delay) {
  return delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
}
