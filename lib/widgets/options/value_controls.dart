import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

/// A preset value as a card, for the via-stop stay picker.
class QuickValueCard extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const QuickValueCard({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentWash(accent) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: selected ? accent : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
