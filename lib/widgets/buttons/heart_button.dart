import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

/// Keeps a place among the favourites, or lets it go.
class HeartButton extends StatelessWidget {
  const HeartButton({
    super.key,
    required this.kept,
    required this.placeName,
    required this.onPressed,
  });

  final bool kept;

  /// Names the place, for a screen reader.
  final String placeName;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      toggled: kept,
      label: kept ? 'Remove $placeName from favourites' : 'Keep $placeName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.lightTick();
          onPressed();
        },
        // The padding widens the tap target leftwards, into the row's dead
        // space, so it grows without the row growing or the heart moving off
        // the column the favourites' edit buttons sit in.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 1, 2),
          // Lucide has no solid heart, so kept reads as accent on a tint and
          // unkept as a pale outline on nothing.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kept
                  ? accent.withValues(alpha: 0.16)
                  : const Color(0x00000000),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.heart,
              size: 18,
              color: kept ? accent : AppColors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
