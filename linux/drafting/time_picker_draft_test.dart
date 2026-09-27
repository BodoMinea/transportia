import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transportia/models/time_selection.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/widgets/time_selection_overlay.dart';

import 'draft_kit.dart';

/// A Sunday afternoon, so the day tiles read Today, Tomorrow, Tue, Wed.
final DateTime _now = DateTime(2026, 9, 27, 14, 7);

Widget _picker({TimeSelection? selection, bool showDepartArriveToggle = true}) {
  return Stack(
    children: [
      const DraftOverMap(sheet: SizedBox.shrink()),
      // Watching the provider rebuilds the overlay once stored settings such
      // as the theme have loaded.
      Builder(
        builder: (context) {
          context.watch<ThemeProvider>();
          return TimeSelectionOverlay(
            currentSelection: selection ?? TimeSelection.now(),
            onSelectionChanged: (_) {},
            onDismiss: () {},
            showDepartArriveToggle: showDepartArriveToggle,
            now: _now,
          );
        },
      ),
    ],
  );
}

/// [shootScreen] takes its picture a single frame after the settle, before
/// the card has faded in; settling first catches it once it has.
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = kDraftPhone,
}) async {
  await pumpDraft(tester, screen, size: size);
  await tester.pumpAndSettle();
  await saveDraft(tester, name);
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDraftFonts);
  setUp(resetDraftStorage);

  testWidgets('opened on now', (tester) async {
    await _shoot(tester, 'now', _picker());
  });

  testWidgets('arrive by tomorrow', (tester) async {
    await _shoot(
      tester,
      'arrive_by_tomorrow',
      _picker(
        selection: TimeSelection(
          dateTime: DateTime(2026, 9, 28, 8, 45),
          isArriveBy: true,
        ),
      ),
    );
  });

  testWidgets('calendar open', (tester) async {
    await pumpDraft(tester, _picker());
    await tester.pumpAndSettle();
    await _tapLabel(tester, 'Open calendar');
    await _tapLabel(tester, 'Next month');
    await saveDraft(tester, 'calendar_open');
  });

  testWidgets('a day from the calendar', (tester) async {
    await _shoot(
      tester,
      'calendar_day',
      _picker(
        selection: TimeSelection(
          dateTime: DateTime(2026, 10, 29, 18, 30),
          isArriveBy: false,
        ),
      ),
    );
  });

  testWidgets('timetables, no toggle', (tester) async {
    await _shoot(tester, 'timetables', _picker(showDepartArriveToggle: false));
  });

  testWidgets('narrow phone', (tester) async {
    await _shoot(tester, 'narrow_360', _picker(), size: const Size(360, 740));
  });

  testWidgets('dark', (tester) async {
    await SharedPreferencesAsync().setString('app_theme', 'dark');
    await _shoot(tester, 'dark', _picker());
  });

  testWidgets('dark calendar', (tester) async {
    await SharedPreferencesAsync().setString('app_theme', 'dark');
    await pumpDraft(tester, _picker());
    await tester.pumpAndSettle();
    await _tapLabel(tester, 'Open calendar');
    await saveDraft(tester, 'dark_calendar');
  });
}
