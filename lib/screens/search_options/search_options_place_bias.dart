import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/place_bias.dart';
import '../../widgets/options/icon_controls.dart';
import 'search_options_rows.dart';

/// How strongly place search favours what is near the rider, down to not
/// sending their position at all.
class SearchOptionsPlaceBiasGroup extends StatelessWidget {
  const SearchOptionsPlaceBiasGroup({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final off = PlaceBias.isOff(value);
    final isDefault = PlaceBias.isDefault(value);

    return OptionsGroup(
      title: 'Place search',
      children: [
        OptionsRow(
          icon: off ? LucideIcons.locateOff : LucideIcons.locateFixed,
          label: 'Prefer nearby places',
          value: off
              ? 'Off'
              : '${value.toStringAsFixed(1)}${isDefault ? ' · default' : ''}',
          muted: off,
          description: off
              ? 'Your location is not sent when you search for a place; '
                    'results are ranked by name alone.'
              : null,
          below: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                const SizedBox(height: 8),
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
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.black.withValues(alpha: 0.55),
        ),
        children: [
          const TextSpan(
            text: 'Why 1.5: ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(
            text:
                'it still finds the shops around you, while far-away '
                'long-distance train stations make it into the results too. ',
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReset,
              child: Text(
                'Back to 1.5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
