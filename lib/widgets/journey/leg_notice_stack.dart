import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/journey_colors.dart';
import '../../utils/leg_notices.dart';

enum _StackMode { full, folded, headline }

/// The notices of one leg, most severe first, in the same place under every
/// kind of leg — a ride, a walk or a change.
///
/// Each is a tinted block. The severity is said three ways, so no one of
/// them has to carry it alone: the tint, the icon's shape, and for a problem
/// the colour of the words.
class LegNoticeStack extends StatelessWidget {
  /// Everything in full: for a leg that cannot be unfolded, where anything
  /// held back could never be read.
  const LegNoticeStack(this.notices, {super.key}) : _mode = _StackMode.full;

  /// The first few, with the operator's longer texts cut short — for a ride
  /// while its stops are folded away. Unfolding the ride shows the rest.
  const LegNoticeStack.folded(this.notices, {super.key})
    : _mode = _StackMode.folded;

  /// The most severe one's title and a count of the rest — for a card with
  /// room for a line, such as the map's. The itinerary has the full story.
  const LegNoticeStack.headline(this.notices, {super.key})
    : _mode = _StackMode.headline;

  final List<LegNotice> notices;
  final _StackMode _mode;

  bool get _folded => _mode != _StackMode.full;

  int get _visible => switch (_mode) {
    _StackMode.full => notices.length,
    _StackMode.folded => _visibleWhenFolded,
    _StackMode.headline => 1,
  };

  /// A folded leg shows this many and counts the rest.
  static const int _visibleWhenFolded = 3;

  /// Lines of an operator's longer text shown while folded.
  static const int _detailLinesWhenFolded = 2;

  /// One line of a notice's title, and the space kept above the stack.
  static const double lineHeight = 18;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    final shown = notices.take(_visible).toList();
    final hidden = notices.length - shown.length;
    return Padding(
      // A card's headline sits in the card's own rhythm; on the itinerary
      // the stack stands a clear line apart from the facts above it.
      padding: EdgeInsets.only(
        top: _mode == _StackMode.headline ? 10 : lineHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, notice) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            _NoticeBlock(
              notice,
              folded: _folded,
              withDetail: _mode != _StackMode.headline,
            ),
          ],
          if (hidden > 0) ...[
            const SizedBox(height: 6),
            Text(
              '+$hidden more',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accentOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeBlock extends StatelessWidget {
  const _NoticeBlock(
    this.notice, {
    required this.folded,
    required this.withDetail,
  });

  final LegNotice notice;
  final bool folded;
  final bool withDetail;

  static const double _titleSize = 13;
  static const double _detailSize = 12;
  static const double _detailLineHeight = 16;

  /// A problem takes the red a missed change turns the spine, so the block
  /// and the line beside it read as one warning.
  static Color _colorOf(BuildContext context, NoticeSeverity severity) =>
      switch (severity) {
        NoticeSeverity.problem => kMissedChangeColor,
        NoticeSeverity.caution => AppColors.alertIcon,
        NoticeSeverity.info => AppColors.accentOf(context),
      };

  static IconData _iconOf(NoticeSeverity severity) => switch (severity) {
    NoticeSeverity.problem => LucideIcons.octagonAlert,
    NoticeSeverity.caution => LucideIcons.triangleAlert,
    NoticeSeverity.info => LucideIcons.info,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(context, notice.severity);
    final detail = withDetail ? notice.detail : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        // On the first line, however many the title and text run to: the
        // icon is exactly a line tall, so its top is the line's top.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconOf(notice.severity),
            size: LegNoticeStack.lineHeight,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: TextStyle(
                    fontSize: _titleSize,
                    height: LegNoticeStack.lineHeight / _titleSize,
                    fontWeight: FontWeight.w600,
                    color: notice.severity == NoticeSeverity.problem
                        ? color
                        : AppColors.black.withValues(alpha: 0.8),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: folded
                        ? LegNoticeStack._detailLinesWhenFolded
                        : null,
                    overflow: folded ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      fontSize: _detailSize,
                      height: _detailLineHeight / _detailSize,
                      color: AppColors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
