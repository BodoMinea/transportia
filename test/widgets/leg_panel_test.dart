import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/widgets/options/icon_controls.dart';
import 'package:transportia/widgets/search/leg_panel.dart';

class _Taps {
  final List<String> log = [];
  VoidCallback tap(String what) =>
      () => log.add(what);
}

Future<_Taps> _pump(
  WidgetTester tester, {
  bool expanded = false,
  GroupState railState = GroupState.some,
  String? changes,
}) async {
  final taps = _Taps();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: LegPanel(
              tooltips: OptionTooltipController(),
              expanded: expanded,
              onExpandedChanged: (full) => taps.log.add('expand $full'),
              sections: [
                LegSection(
                  mark: const Icon(LucideIcons.trainFront),
                  title: 'Rail',
                  state: railState,
                  onToggle: taps.tap('rail'),
                  choices: [
                    LegChoice(
                      label: 'Regional rail',
                      selected: true,
                      onPressed: taps.tap('regional rail'),
                    ),
                  ],
                ),
              ],
              options: [
                LegOption.toggle(
                  mark: const RegionalGlyph(),
                  title: 'Regional only',
                  on: false,
                  onToggle: taps.tap('regional only'),
                ),
                LegOption.value(
                  icon: LucideIcons.waypoints,
                  title: 'Maximum changes',
                  value: changes,
                  slider: const SizedBox(height: 10, key: Key('slider')),
                ),
                LegOption.toggle(
                  mark: const Icon(LucideIcons.mapPin),
                  title: 'Travel through a stop',
                  on: false,
                  onToggle: taps.tap('via'),
                  inCompactRow: false,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return taps;
}

Finder _pick(String label) =>
    find.byWidgetPredicate((w) => w is IconPick && w.label == label);

void main() {
  group('compact', () {
    testWidgets('a section icon switches its section', (tester) async {
      final taps = await _pump(tester);
      await tester.tap(_pick('Rail'));
      expect(taps.log, ['rail']);
    });

    testWidgets('partly on is its own state, not half of on', (tester) async {
      await _pump(tester);
      final rail = tester.widget<IconPick>(_pick('Rail'));
      expect(rail.partial, isTrue);
      expect(rail.selected, isFalse);
    });

    testWidgets('an action is kept for the full view', (tester) async {
      await _pump(tester);
      expect(_pick('Travel through a stop'), findsNothing);
      expect(_pick('Regional only'), findsOneWidget);
    });

    testWidgets('no limit is the infinity sign, a limit its number', (
      tester,
    ) async {
      await _pump(tester);
      final chip = tester.widget<ValueChip>(find.byType(ValueChip));
      expect(chip.valueIcon, LucideIcons.infinity);

      await _pump(tester, changes: '2');
      final limited = tester.widget<ValueChip>(find.byType(ValueChip));
      expect(limited.value, '2');
      expect(limited.valueIcon, isNull);
    });

    testWidgets('a value chip opens the full view, where its slider is', (
      tester,
    ) async {
      final taps = await _pump(tester);
      expect(find.byKey(const Key('slider')), findsNothing);
      await tester.tap(find.byType(ValueChip));
      expect(taps.log, ['expand true']);
    });

    testWidgets('the link opens the full view', (tester) async {
      final taps = await _pump(tester);
      await tester.tap(find.text('All options'));
      expect(taps.log, ['expand true']);
    });
  });

  group('full', () {
    testWidgets('each section is a heading with its choices under it', (
      tester,
    ) async {
      final taps = await _pump(tester, expanded: true);
      expect(find.byType(IconPick), findsNothing);
      expect(find.text('RAIL'), findsOneWidget);

      await tester.tap(find.text('Regional rail'));
      expect(taps.log, ['regional rail']);
    });

    testWidgets('the whole heading switches its section', (tester) async {
      final taps = await _pump(tester, expanded: true);
      final row = tester.getRect(
        find.byWidgetPredicate((w) => w is LegHeading && w.title == 'Rail'),
      );
      await tester.tapAt(Offset(row.right - 10, row.center.dy));
      await tester.tapAt(Offset(row.left + 5, row.center.dy));
      expect(taps.log, ['rail', 'rail']);
    });

    testWidgets('choices and sliders start where the headings\' text does', (
      tester,
    ) async {
      await _pump(tester, expanded: true);
      final title = tester.getTopLeft(find.text('RAIL'));
      final choice = tester.getTopLeft(find.byType(Wrap));
      expect(choice.dx, title.dx);
    });

    testWidgets('every option is there, slider open and action included', (
      tester,
    ) async {
      final taps = await _pump(tester, expanded: true);
      expect(find.byKey(const Key('slider')), findsOneWidget);
      expect(find.byIcon(LucideIcons.infinity), findsOneWidget);

      await tester.tap(find.text('TRAVEL THROUGH A STOP'));
      await tester.tap(find.text('REGIONAL ONLY'));
      expect(taps.log, ['via', 'regional only']);
    });

    testWidgets('a value is not a switch: its heading does nothing', (
      tester,
    ) async {
      final taps = await _pump(tester, expanded: true);
      await tester.tap(find.text('MAXIMUM CHANGES'));
      expect(taps.log, isEmpty);
    });

    testWidgets('the link closes it again', (tester) async {
      final taps = await _pump(tester, expanded: true);
      await tester.tap(find.text('Fewer options'));
      expect(taps.log, ['expand false']);
    });
  });
}
