class TimeSelection {
  final DateTime dateTime;
  final bool isArriveBy;
  final bool _isDefaultNow;

  const TimeSelection({
    required this.dateTime,
    required this.isArriveBy,
    bool isDefaultNow = false,
  }) : _isDefaultNow = isDefaultNow;

  factory TimeSelection.now() {
    return TimeSelection(
      dateTime: DateTime.now(),
      isArriveBy: false,
      isDefaultNow: true,
    );
  }

  bool get isNow => _isDefaultNow;

  String toApiDateFormat() {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';
  }

  String toApiTimeFormat() {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String toDisplayString({DateTime? now}) {
    if (isNow) return 'Now';

    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (selectedDay == today) {
      dateStr = 'Today';
    } else if (selectedDay == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}';
    }

    final timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr $timeStr';
  }

  /// The search card's line under the origin: what the rider will do, and
  /// when. Today goes without saying, so only another day is named.
  String toSearchLabel({DateTime? now}) {
    if (isNow) return 'Leave now';
    final when = toDisplayString(now: now);
    final time = when.startsWith(_todayPrefix)
        ? when.substring(_todayPrefix.length)
        : when;
    return '${isArriveBy ? 'Arrive' : 'Leave'} $time';
  }

  static const String _todayPrefix = 'Today ';

  Map<String, dynamic> toJson() => {
    'dateTime': dateTime.toIso8601String(),
    'isArriveBy': isArriveBy,
    'isDefaultNow': _isDefaultNow,
  };

  factory TimeSelection.fromJson(Map<String, dynamic> json) {
    return TimeSelection(
      dateTime: DateTime.parse(json['dateTime'] as String),
      isArriveBy: json['isArriveBy'] as bool? ?? false,
      isDefaultNow: json['isDefaultNow'] as bool? ?? false,
    );
  }

  TimeSelection copyWith({
    DateTime? dateTime,
    bool? isArriveBy,
    bool? isDefaultNow,
  }) {
    return TimeSelection(
      dateTime: dateTime ?? this.dateTime,
      isArriveBy: isArriveBy ?? this.isArriveBy,
      isDefaultNow: isDefaultNow ?? _isDefaultNow,
    );
  }
}
