import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/reported_time.dart';

final DateTime _planned = DateTime(2026, 6, 1, 9, 35);

void main() {
  test('with neither time there is nothing to print', () {
    expect(ReportedTime.from(null, null, isLive: true), isNull);
  });

  test('a late service shows the real time, and how late it is', () {
    final time = ReportedTime.from(
      _planned.add(const Duration(minutes: 3)),
      _planned,
      isLive: true,
    )!;
    expect(time.shown, _planned.add(const Duration(minutes: 3)));
    expect(time.delay, const Duration(minutes: 3));
    expect(time.isLive, isTrue);
  });

  test('an early one is a negative delay', () {
    final time = ReportedTime.from(
      _planned.subtract(const Duration(minutes: 2)),
      _planned,
      isLive: true,
    )!;
    expect(time.delay, const Duration(minutes: -2));
  });

  test('under a minute out is on time', () {
    final time = ReportedTime.from(
      _planned.add(const Duration(seconds: 40)),
      _planned,
      isLive: true,
    )!;
    expect(time.delay, isNull);
  });

  test('only a plan: that is the time, and nothing is late against it', () {
    final time = ReportedTime.from(null, _planned, isLive: false)!;
    expect(time.shown, _planned);
    expect(time.delay, isNull);
  });

  test('only a real time: that is the time, with no plan to compare', () {
    final real = _planned.add(const Duration(minutes: 5));
    final time = ReportedTime.from(real, null, isLive: true)!;
    expect(time.shown, real);
    expect(time.delay, isNull);
  });

  test('whether it is live comes from the caller, not from having a time', () {
    // The planner fills a real time in even when nobody is reporting.
    final time = ReportedTime.from(_planned, _planned, isLive: false)!;
    expect(time.isLive, isFalse);
  });
}
