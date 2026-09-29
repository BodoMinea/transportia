import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/place_bias.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/options/icon_controls.dart';
import '../../widgets/section_title.dart';

/// How strongly place search favours what is near the rider, down to not
/// sending their position at all.
class SearchOptionsPlaceBiasCard extends StatelessWidget {
  const SearchOptionsPlaceBiasCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final off = PlaceBias.isOff(value);
    final isDefault = PlaceBias.isDefault(value);
    final muted = AppColors.black.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Place search'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    off ? LucideIcons.locateOff : LucideIcons.locateFixed,
                    size: 18,
                    color: off ? muted : accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      off ? 'Location not used' : 'Prefer nearby places',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                  Text(
                    off
                        ? 'Off'
                        : '${value.toStringAsFixed(1)}'
                              '${isDefault ? ' · default' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: off ? muted : accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                off
                    ? 'Your location is not sent when you search for a '
                          'place. Results are ranked by name alone.'
                    : 'How far a nearby place may outrank a better match '
                          'further away.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 12),
              OptionSlider(
                value: PlaceBias.toPosition(value).toDouble(),
                max: PlaceBias.positions.toDouble(),
                divisions: PlaceBias.positions,
                semanticLabel: 'Location bias',
                onChanged: (position) =>
                    onChanged(PlaceBias.fromPosition(position.round())),
              ),
              const SliderScaleLabels(labels: ['Off', 'Closest first']),
              if (!off && !isDefault) ...[
                const SizedBox(height: 14),
                _DefaultHint(onReset: () => onChanged(PlaceBias.defaultValue)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Why the default is 1.5, for someone about to move away from it.
class _DefaultHint extends StatelessWidget {
  const _DefaultHint({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 14,
                color: AppColors.black.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                'Why 1.5',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Measured from Berlin: at 1.5, “Paris” finds the city and both '
            'of its main stations before any local shop with Paris in its '
            'name. Stronger, and nearby shops push the stations down. '
            'Weaker, and far-away stops that merely share a name crowd in.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReset,
            child: Text(
              'Back to 1.5',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
