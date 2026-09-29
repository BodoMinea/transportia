import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import 'app_toggle_switch.dart';
import 'settings_tile.dart';

/// A setting that is simply on or off, on the page's faint card.
class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.04)),
      ),
      child: SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailingIcon: null,
        trailing: AppToggleSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}
