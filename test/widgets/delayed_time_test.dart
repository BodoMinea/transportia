import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/journey_colors.dart';
import 'package:transportia/utils/reported_time.dart';
import 'package:transportia/widgets/delayed_time.dart';

final DateTime _planned = DateTime(2026, 6, 1, 9, 35);

ReportedTime _late(int minutes, {bool isLive = true}) => ReportedTime.from(
  _planned.add(Duration(minutes: minutes)),
  _planned,
  isLive: isLive,
)!;

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

Color? _colourOf(WidgetTester tester, String text) {
  final rich = tester.widgetList<Text>(find.byType(Text));
  for (final widget in rich) {
    final span = widget.textSpan;
    if (span != null) {
      Color? found;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == text) {
          found = child.style?.color;
          return false;
        }
        return true;
      });
      if (found != null) return found;
    }
    if (widget.data == text) return widget.style?.color;
  }
  return null;
}

void main() {
  testWidgets('a late time is printed as it really is, not as planned', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.start(_late(3)));
    expect(find.text('09:38'), findsOne);
    expect(find.textContaining('09:35'), findsNothing);
    expect(find.text('+3m'), findsOne);
  });

  testWidgets('the time is red and the delay under it grey', (tester) async {
    await _pump(tester, DelayedTime.start(_late(3)));
    expect(_colourOf(tester, '09:38'), kLateDeparture);
    expect(_colourOf(tester, '+3m'), delayNoteColor());
  });

  testWidgets('beside a departure, an arrival takes the lighter red', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.start(_late(3), isArrival: true));
    expect(_colourOf(tester, '09:38'), kLateArrival);
  });

  testWidgets('on time and reported is green, with no delay', (tester) async {
    await _pump(tester, DelayedTime.start(_late(0)));
    expect(_colourOf(tester, '09:35'), kOnTimeDeparture);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('the label stays out of the time\'s colour', (tester) async {
    await _pump(tester, DelayedTime.start(_late(3), label: 'Arr'));
    expect(_colourOf(tester, 'Arr '), isNot(kLateDeparture));
    expect(_colourOf(tester, '09:38'), kLateDeparture);
  });

  testWidgets('no time at all keeps the row with a placeholder', (
    tester,
  ) async {
    await _pump(tester, const DelayedTime.start(null, label: 'Arr'));
    expect(find.textContaining('--:--'), findsOne);
  });

  testWidgets('the delay sits under the time, starting where it starts', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.start(_late(3)));
    final time = tester.getRect(find.text('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.top, greaterThanOrEqualTo(time.bottom));
    expect(delay.left, time.left);
  });

  testWidgets('.end lines the delay up with the end of the time', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.end(_late(3)));
    final time = tester.getRect(find.text('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.top, greaterThanOrEqualTo(time.bottom));
    expect(delay.right, time.right);
  });

  testWidgets('with a label, the delay is under the time, not the label', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.start(_late(3), label: 'Arr'));
    final label = tester.getRect(find.text('Arr '));
    final time = tester.getRect(find.text('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.left, time.left);
    expect(delay.left, greaterThanOrEqualTo(label.right));
  });

  testWidgets('a delay makes the time taller, so its row grows with it', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.start(_late(0)));
    final onTime = tester.getSize(find.byType(DelayedTime)).height;
    await _pump(tester, DelayedTime.start(_late(3)));
    final late = tester.getSize(find.byType(DelayedTime)).height;
    expect(late, greaterThan(onTime));
  });

  testWidgets('.inline puts the delay after the time, on its line', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.inline(_late(3), label: 'Arr'));
    final label = tester.getRect(find.text('Arr '));
    final time = tester.getRect(find.text('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.left, greaterThan(time.right));
    expect(delay.bottom, closeTo(time.bottom, 1));
    expect(time.left, greaterThanOrEqualTo(label.right));
  });

  testWidgets('.inline drops the delay to the next line with no room', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 70,
        child: Align(
          alignment: Alignment.centerLeft,
          child: DelayedTime.inline(_late(3), label: 'Arr'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final time = tester.getRect(find.text('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.top, greaterThanOrEqualTo(time.bottom));
  });
}
