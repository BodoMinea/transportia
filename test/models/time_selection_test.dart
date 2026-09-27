import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/time_selection.dart';

final DateTime _now = DateTime(2026, 9, 27, 12);

void main() {
  group('toSearchLabel', () {
    test('the default reads as leaving now', () {
      expect(TimeSelection.now().toSearchLabel(now: _now), 'Leave now');
    });

    test('today goes unsaid', () {
      final leave = TimeSelection(
        dateTime: DateTime(2026, 9, 27, 14, 5),
        isArriveBy: false,
      );
      final arrive = TimeSelection(
        dateTime: DateTime(2026, 9, 27, 14, 5),
        isArriveBy: true,
      );

      expect(leave.toSearchLabel(now: _now), 'Leave 14:05');
      expect(arrive.toSearchLabel(now: _now), 'Arrive 14:05');
    });

    test('another day is named', () {
      final tomorrow = TimeSelection(
        dateTime: DateTime(2026, 9, 28, 8, 15),
        isArriveBy: false,
      );
      final later = TimeSelection(
        dateTime: DateTime(2026, 10, 3, 9, 0),
        isArriveBy: true,
      );

      expect(tomorrow.toSearchLabel(now: _now), 'Leave Tomorrow 8:15');
      expect(later.toSearchLabel(now: _now), 'Arrive 3/10 9:00');
    });

    test('just before midnight, tomorrow is still named', () {
      final lateNight = DateTime(2026, 9, 27, 23, 59);
      final justAfter = TimeSelection(
        dateTime: DateTime(2026, 9, 28, 0, 1),
        isArriveBy: false,
      );

      expect(justAfter.toSearchLabel(now: lateNight), 'Leave Tomorrow 0:01');
    });
  });
}
