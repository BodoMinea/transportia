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
  const PlatformUnknownNotice({super.key});

  static const String message =
      'Platform unknown: walking route and time may be off.';

  /// One line of the notice. The itinerary leaves this much space above it,
  /// so the warning stands apart from the facts about the walk.
  static const double lineHeight = 18;
  static const double _fontSize = 13;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        // Centred on the whole of the text, one line or two.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: AppColors.alertIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: _fontSize,
                height: lineHeight / _fontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
