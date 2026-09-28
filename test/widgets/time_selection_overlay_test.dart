import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/widgets/time_selection_overlay.dart';

/// Thursday afternoon; tomorrow is Friday the 25th.
final DateTime _now = DateTime(2026, 9, 24, 14, 7);

Future<List<TimeSelection>> _pumpOverlay(
  WidgetTester tester, {
  required TimeSelection selection,
  bool showDepartArriveToggle = true,
  DateTime? now,
}) async {
  final confirmed = <TimeSelection>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: TimeSelectionOverlay(
          currentSelection: selection,
          onSelectionChanged: confirmed.add,
          onDismiss: () {},
          showDepartArriveToggle: showDepartArriveToggle,
          now: now ?? _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return confirmed;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Drags a wheel by whole rows; positive rows move to later values.
Future<void> _spin(WidgetTester tester, String wheel, int rows) async {
  // Two extra pixels past the row line so the snap lands on the intended row
  // rather than rounding back.
  await tester.drag(
    find.byKey(ValueKey(wheel)),
    Offset(0, -(rows * 44.0 + rows.sign * 2)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a "now" selection opens on the current time, not its own', (
    tester,
  ) async {
    final stale = TimeSelection(
      dateTime: DateTime(2026, 9, 20, 3, 30),
      isArriveBy: false,
      isDefaultNow: true,
    );
    final confirmed = await _pumpOverlay(tester, selection: stale);

    await _tap(tester, 'Confirm');

    expect(confirmed.single.dateTime, DateTime(2026, 9, 24, 14, 7));
    expect(confirmed.single.isNow, isFalse);
  });

  testWidgets('offers the next four days by name, then the calendar', (
    tester,
  ) async {
    await _pumpOverlay(tester, selection: TimeSelection.now());

    for (final label in ['Today', 'Tmrw', 'Sat', 'Sun']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Open calendar'), findsOneWidget);
    // Abbreviated to fit the tile, but read out in full.
    expect(tester.widget<Text>(find.text('Tmrw')).semanticsLabel, 'Tomorrow');
    // The four days sit side by side with the calendar, none scrolled away.
    final widths = [
      for (final label in ['Today', 'Tmrw', 'Sat', 'Sun'])
        tester
            .getSize(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .width,
      tester
          .getSize(
            find.descendant(
              of: find.bySemanticsLabel('Open calendar'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .width,
    ];
    expect(widths.toSet(), hasLength(1));
  });

  testWidgets('one tap picks another day, keeping the time', (tester) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection(
        dateTime: DateTime(2026, 9, 24, 9, 15),
        isArriveBy: false,
      ),
    );

    await _tap(tester, 'Tmrw');
    await _tap(tester, 'Confirm');

    expect(confirmed.single.dateTime, DateTime(2026, 9, 25, 9, 15));
  });

  testWidgets('the wheels loop, so minutes run from 58 on to 01', (
    tester,
  ) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection(
        dateTime: DateTime(2026, 9, 24, 23, 58),
        isArriveBy: false,
      ),
    );

    await _spin(tester, 'minuteWheel', 3);
    await _spin(tester, 'hourWheel', -2);
    await _tap(tester, 'Confirm');

    expect(confirmed.single.dateTime, DateTime(2026, 9, 24, 21, 1));
  });

  testWidgets('a shortcut sets the time from now, whatever was selected', (
    tester,
  ) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection(
        dateTime: DateTime(2026, 9, 26, 6, 0),
        isArriveBy: false,
      ),
    );

    await _tap(tester, 'In 1 h');
    await _tap(tester, 'Confirm');

    expect(confirmed.single.dateTime, DateTime(2026, 9, 24, 15, 7));
  });

  testWidgets('a shortcut past midnight moves on to the next day', (
    tester,
  ) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection.now(),
      now: DateTime(2026, 9, 24, 23, 50),
    );

    await _tap(tester, 'In 30 min');
    await _tap(tester, 'Confirm');

    expect(confirmed.single.dateTime, DateTime(2026, 9, 25, 0, 20));
  });

  testWidgets('arrive-by is carried into the confirmed selection', (
    tester,
  ) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection.now(),
    );

    await _tap(tester, 'Arrive by');
    await _tap(tester, 'Confirm');

    expect(confirmed.single.isArriveBy, isTrue);
  });

  testWidgets('without the toggle there is no depart or arrive choice', (
    tester,
  ) async {
    await _pumpOverlay(
      tester,
      selection: TimeSelection.now(),
      showDepartArriveToggle: false,
    );

    expect(find.text('Arrive by'), findsNothing);
  });

  testWidgets('"Now" hands back a live now selection', (tester) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection(
        dateTime: DateTime(2026, 9, 25, 8, 0),
        isArriveBy: true,
      ),
    );

    await _tap(tester, 'Now');

    expect(confirmed.single.isNow, isTrue);
  });

  testWidgets('a selection already in the past stays selectable', (
    tester,
  ) async {
    final confirmed = await _pumpOverlay(
      tester,
      selection: TimeSelection(
        dateTime: DateTime(2026, 9, 22, 8, 0),
        isArriveBy: false,
      ),
    );

    expect(find.text('22 Sep'), findsOneWidget);
    await _tap(tester, 'Confirm');
    expect(confirmed.single.dateTime, DateTime(2026, 9, 22, 8, 0));
  });

  group('calendar', () {
    Finder inCalendar(String text) => find.descendant(
      of: find.byKey(const ValueKey('monthCalendar')),
      matching: find.text(text),
    );

    Future<void> tapLabel(WidgetTester tester, String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    testWidgets('reaches a day a month off in a few taps, keeping the time', (
      tester,
    ) async {
      final confirmed = await _pumpOverlay(
        tester,
        selection: TimeSelection(
          dateTime: DateTime(2026, 9, 24, 9, 15),
          isArriveBy: false,
        ),
      );

      await tapLabel(tester, 'Open calendar');
      expect(find.text('September 2026'), findsOneWidget);

      await tapLabel(tester, 'Next month');
      await tester.tap(inCalendar('29'));
      await tester.pumpAndSettle();

      // Picking a day closes the calendar and brings the wheels back.
      expect(find.byKey(const ValueKey('monthCalendar')), findsNothing);
      expect(find.byKey(const ValueKey('hourWheel')), findsOneWidget);

      await _tap(tester, 'Confirm');
      expect(confirmed.single.dateTime, DateTime(2026, 10, 29, 9, 15));
    });

    testWidgets('days before today cannot be picked', (tester) async {
      final confirmed = await _pumpOverlay(
        tester,
        selection: TimeSelection(
          dateTime: DateTime(2026, 9, 24, 9, 15),
          isArriveBy: false,
        ),
      );

      await tapLabel(tester, 'Open calendar');
      await tester.tap(inCalendar('23'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('monthCalendar')), findsOneWidget);
      await _tap(tester, 'Confirm');
      expect(confirmed.single.dateTime, DateTime(2026, 9, 24, 9, 15));
    });

    testWidgets('does not page back before the current month', (tester) async {
      await _pumpOverlay(tester, selection: TimeSelection.now());

      await tapLabel(tester, 'Open calendar');
      await tapLabel(tester, 'Previous month');

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('pages no further than a year ahead', (tester) async {
      await _pumpOverlay(tester, selection: TimeSelection.now());

      await tapLabel(tester, 'Open calendar');
      for (var i = 0; i < 14; i++) {
        await tapLabel(tester, 'Next month');
      }

      expect(find.text('September 2027'), findsOneWidget);
      // 24 September 2027 is the last day within reach.
      await tester.tap(inCalendar('25'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('monthCalendar')), findsOneWidget);
    });

    testWidgets('a day picked beyond the tiles shows on the calendar tile', (
      tester,
    ) async {
      final confirmed = await _pumpOverlay(
        tester,
        selection: TimeSelection(
          dateTime: DateTime(2026, 9, 24, 9, 15),
          isArriveBy: false,
        ),
      );

      await tapLabel(tester, 'Open calendar');
      await tapLabel(tester, 'Next month');
      await tapLabel(tester, 'Next month');
      await tester.tap(inCalendar('20'));
      await tester.pumpAndSettle();

      expect(find.text('20 Nov'), findsOneWidget);
      await _tap(tester, 'Confirm');
      expect(confirmed.single.dateTime, DateTime(2026, 11, 20, 9, 15));
    });

    testWidgets('the calendar button closes it again', (tester) async {
      await _pumpOverlay(tester, selection: TimeSelection.now());

      await tapLabel(tester, 'Open calendar');
      await tapLabel(tester, 'Close calendar');

      expect(find.byKey(const ValueKey('monthCalendar')), findsNothing);
      expect(find.byKey(const ValueKey('minuteWheel')), findsOneWidget);
    });
  });
}
