import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';

/// The line under a change whose platforms the feed does not have. See
/// `Changeover.platformUnknown`.
///
/// Amber rather than the missed-change red: the change may well work, the
/// numbers for the walk are just a guess. The icon carries the colour; the
/// words stay in the text colour, since amber text is hard to read on white.
class PlatformUnknownNotice extends StatelessWidget {
  /// The whole sentence, on a line of its own under the change.
  const PlatformUnknownNotice({super.key}) : _compact = false;

  /// Two words, to sit beside a heading where there is no room for a line.
  const PlatformUnknownNotice.compact({super.key}) : _compact = true;

  final bool _compact;

  static const String message =
      'Platform unknown: walking route and time may be off.';
  static const String _short = 'Platform unknown';

  @override
  Widget build(BuildContext context) {
    final text = Text(
      _compact ? _short : message,
      maxLines: _compact ? 1 : null,
      overflow: _compact ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: _compact ? 12 : 13,
        fontWeight: FontWeight.w600,
        color: AppColors.black.withValues(alpha: 0.75),
      ),
    );
    return Semantics(
      container: true,
      // The short form still says the whole thing to a screen reader.
      label: _compact ? message : null,
      excludeSemantics: _compact,
      child: Row(
        mainAxisSize: _compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              LucideIcons.triangleAlert,
              size: 14,
              color: AppColors.alertIcon,
            ),
          ),
          const SizedBox(width: 6),
          if (_compact) Flexible(child: text) else Expanded(child: text),
        ],
      ),
    );
  }
}
