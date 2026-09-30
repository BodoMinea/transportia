import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:transportia/utils/leg_notices.dart';
import 'package:transportia/widgets/journey/leg_notice_stack.dart';

const _problem = LegNotice(NoticeSeverity.problem, 'Problem');
const _caution = LegNotice(
  NoticeSeverity.caution,
  'Caution',
  detail:
      'A long text from the operator that goes on for some time, '
      'explaining what is happening and what to do about it, over lines.',
);
const _info = LegNotice(NoticeSeverity.info, 'Info');
const _extra = LegNotice(NoticeSeverity.info, 'Extra');

Future<void> _pump(WidgetTester tester, Widget stack) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, child: stack),
    ),
  ),
);

void main() {
  testWidgets('nothing to say takes no room', (tester) async {
    await _pump(tester, const LegNoticeStack([]));
    expect(tester.getSize(find.byType(LegNoticeStack)).height, 0);
  });

  testWidgets('in full, every notice and every word', (tester) async {
    await _pump(
      tester,
      const LegNoticeStack([_problem, _caution, _info, _extra]),
    );
    for (final title in ['Problem', 'Caution', 'Info', 'Extra']) {
      expect(find.text(title), findsOne);
    }
    expect(find.textContaining('more'), findsNothing);
    final detail = tester.widget<Text>(find.text(_caution.detail!));
    expect(detail.maxLines, isNull);
  });

  testWidgets('folded, three and a count of the rest', (tester) async {
    await _pump(
      tester,
      const LegNoticeStack.folded([_problem, _caution, _info, _extra]),
    );
    expect(find.text('Extra'), findsNothing);
    expect(find.text('+1 more'), findsOne);
    final detail = tester.widget<Text>(find.text(_caution.detail!));
    expect(detail.maxLines, 2);
  });

  testWidgets('a headline is the first title alone', (tester) async {
    await _pump(
      tester,
      const LegNoticeStack.headline([_caution, _info, _extra]),
    );
    expect(find.text('Caution'), findsOne);
    expect(find.text(_caution.detail!), findsNothing);
    expect(find.text('Info'), findsNothing);
    expect(find.text('+2 more'), findsOne);
  });

  testWidgets('each severity has its own shape, not only its colour', (
    tester,
  ) async {
    await _pump(tester, const LegNoticeStack([_problem, _caution, _info]));
    expect(find.byIcon(LucideIcons.octagonAlert), findsOne);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOne);
    expect(find.byIcon(LucideIcons.info), findsOne);
  });

  testWidgets('the icon sits on the first line, however many follow', (
    tester,
  ) async {
    await _pump(tester, const LegNoticeStack([_caution, _info]));
    for (final (icon, title) in [
      (LucideIcons.triangleAlert, 'Caution'),
      (LucideIcons.info, 'Info'),
    ]) {
      final iconTop = tester.getTopLeft(find.byIcon(icon)).dy;
      final titleTop = tester.getTopLeft(find.text(title)).dy;
      expect(iconTop, titleTop);
    }
  });
}
