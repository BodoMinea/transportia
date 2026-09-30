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
    await _pump(tester, DelayedTime.inline(_late(3)));
    expect(find.textContaining('09:38'), findsOne);
    expect(find.textContaining('09:35'), findsNothing);
    expect(find.text('+3m'), findsOne);
  });

  testWidgets('the time is red and the delay beside it grey', (tester) async {
    await _pump(tester, DelayedTime.inline(_late(3)));
    expect(_colourOf(tester, '09:38'), kLateDeparture);
    expect(_colourOf(tester, '+3m'), delayNoteColor());
  });

  testWidgets('beside a departure, an arrival takes the lighter red', (
    tester,
  ) async {
    await _pump(tester, DelayedTime.inline(_late(3), isArrival: true));
    expect(_colourOf(tester, '09:38'), kLateArrival);
  });

  testWidgets('on time and reported is green, with no delay', (tester) async {
    await _pump(tester, DelayedTime.inline(_late(0)));
    expect(_colourOf(tester, '09:35'), kOnTimeDeparture);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('the label stays out of the time\'s colour', (tester) async {
    await _pump(tester, DelayedTime.inline(_late(3), label: 'Arr'));
    expect(_colourOf(tester, 'Arr '), isNot(kLateDeparture));
    expect(_colourOf(tester, '09:38'), kLateDeparture);
  });

  testWidgets('no time at all keeps the row with a placeholder', (
    tester,
  ) async {
    await _pump(tester, const DelayedTime.inline(null, label: 'Arr'));
    expect(find.textContaining('--:--'), findsOne);
  });

  testWidgets('stacked puts the delay under the time', (tester) async {
    await _pump(tester, DelayedTime.stacked(_late(3)));
    final time = tester.getTopLeft(find.textContaining('09:38'));
    final delay = tester.getTopLeft(find.text('+3m'));
    expect(delay.dy, greaterThan(time.dy));
  });

  testWidgets('inline puts it after the time on the same line', (tester) async {
    await _pump(tester, DelayedTime.inline(_late(3)));
    final time = tester.getRect(find.textContaining('09:38'));
    final delay = tester.getRect(find.text('+3m'));
    expect(delay.left, greaterThan(time.right));
    expect(delay.bottom, closeTo(time.bottom, 4));
  });
}
