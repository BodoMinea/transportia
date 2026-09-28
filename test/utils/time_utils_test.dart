import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/time_utils.dart';

void main() {
  group('two moments in the same minute', () {
    test('seconds within one minute do not separate them', () {
      // The whole point: a timetable prints minutes, so anything finer than a
      // minute is noise when comparing a clock against one.
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3),
          DateTime.utc(2026, 6, 1, 10, 3, 59),
        ),
        isTrue,
      );
    });

    test('a second past the minute is the next minute', () {
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3, 59),
          DateTime.utc(2026, 6, 1, 10, 4),
        ),
        isFalse,
      );
    });

    test('the same wall clock on different days is not the same minute', () {
      expect(
        isSameMinute(
          DateTime.utc(2026, 6, 1, 10, 3),
          DateTime.utc(2026, 6, 2, 10, 3),
        ),
        isFalse,
      );
    });

    test('compares local time, so a UTC and a local reading agree', () {
      final utc = DateTime.utc(2026, 6, 1, 10, 3);
      expect(isSameMinute(utc, utc.toLocal()), isTrue);
    });
  });

  group('calendar days', () {
    test('runs from the first day to the last, both included', () {
      expect(calendarDays(DateTime(2026, 9, 29), DateTime(2026, 10, 2)), [
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
      ]);
    });

    test('ignores the time of day at either end', () {
      expect(
        calendarDays(
          DateTime(2026, 9, 24, 23, 59),
          DateTime(2026, 9, 25, 0, 1),
        ),
        [DateTime(2026, 9, 24), DateTime(2026, 9, 25)],
      );
    });

    test('a single day is one entry', () {
      expect(
        calendarDays(DateTime(2026, 9, 24, 8), DateTime(2026, 9, 24, 20)),
        [DateTime(2026, 9, 24)],
      );
    });

    test('is empty when the last day comes first', () {
      expect(
        calendarDays(DateTime(2026, 9, 25), DateTime(2026, 9, 24)),
        isEmpty,
      );
    });

    test('lands on midnight across a daylight-saving switch', () {
      // Whatever zone the test runs in, every entry must be a local midnight
      // and each a distinct day; stepping 24 hours would break one of these
      // in any zone that changes clocks in late October.
      final days = calendarDays(DateTime(2026, 10, 20), DateTime(2026, 11, 5));
      expect(days, hasLength(17));
      expect(days.every((d) => d.hour == 0 && d.minute == 0), isTrue);
    });
  });

  group('short date parts', () {
    test('weekday name', () {
      expect(formatWeekday(DateTime(2026, 9, 24)), 'Thu');
      expect(formatWeekday(DateTime(2026, 9, 27)), 'Sun');
    });

    test('day and month', () {
      expect(formatDayMonth(DateTime(2026, 9, 5)), '5 Sep');
      expect(formatDayMonth(DateTime(2026, 12, 31)), '31 Dec');
    });
  });

  group('month grid', () {
    test('pads to Monday before the 1st and to Sunday after the last', () {
      // September 2026 starts on a Tuesday and ends on a Wednesday.
      final grid = monthGrid(DateTime(2026, 9, 17));
      expect(grid, hasLength(35));
      expect(grid.first, isNull);
      expect(grid[1], DateTime(2026, 9, 1));
      expect(grid[30], DateTime(2026, 9, 30));
      expect(grid.sublist(31), everyElement(isNull));
    });

    test('a month starting on Monday has no leading blanks', () {
      expect(monthGrid(DateTime(2026, 6)).first, DateTime(2026, 6, 1));
    });

    test('a 28-day February from a Monday fills exactly four weeks', () {
      final grid = monthGrid(DateTime(2027, 2));
      expect(grid, hasLength(28));
      expect(grid, everyElement(isNotNull));
    });

    test('a month reaching into a sixth week gets six rows', () {
      // August 2026 starts on a Saturday.
      final grid = monthGrid(DateTime(2026, 8));
      expect(grid, hasLength(42));
      expect(grid[5], DateTime(2026, 8, 1));
      expect(grid[35], DateTime(2026, 8, 31));
    });

    test('knows the leap day', () {
      expect(monthGrid(DateTime(2028, 2)), contains(DateTime(2028, 2, 29)));
      expect(monthGrid(DateTime(2027, 2)), isNot(contains(null)));
    });
  });

  test('month and year', () {
    expect(formatMonthYear(DateTime(2026, 9, 25)), 'September 2026');
  });
}
