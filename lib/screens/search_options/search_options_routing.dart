import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../models/transitous/server_config.dart';
import '../../widgets/app_toggle_switch.dart';
import '../../widgets/options/icon_controls.dart';
import '../../widgets/options/selectable_tick.dart';
import 'search_options_rows.dart';

/// How transfers are walked, and how much slack each one gets.
class SearchOptionsTransfersGroup extends StatelessWidget {
  const SearchOptionsTransfersGroup({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  /// The most extra time the slider offers per transfer.
  static const int _maxBufferMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final minutes = options.additionalTransferTime.inMinutes;
    return OptionsGroup(
      title: 'Transfers',
      children: [
        // A server without street routing cannot route transfers, so
        // offering the switch would be misleading.
        if (capabilities.hasRoutedTransfers)
          OptionsRow(
            icon: LucideIcons.footprints,
            label: 'Walk real paths',
            description:
                'Route transfers on foot instead of using the '
                'timetable’s fixed times.',
            onTap: () => onChanged(
              options.copyWith(useRoutedTransfers: !options.useRoutedTransfers),
            ),
            trailing: AppToggleSwitch(
              value: options.useRoutedTransfers,
              onChanged: (value) =>
                  onChanged(options.copyWith(useRoutedTransfers: value)),
            ),
          ),
        OptionsRow(
          icon: LucideIcons.clock4,
          label: 'Extra time per transfer',
          value: minutes == 0 ? 'None' : '$minutes min',
          muted: minutes == 0,
          below: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OptionSlider(
                value: minutes.toDouble(),
                max: _maxBufferMinutes.toDouble(),
                divisions: _maxBufferMinutes,
                semanticLabel: 'Extra time per transfer',
                onChanged: (value) => onChanged(
                  options.copyWith(
                    additionalTransferTime: Duration(minutes: value.round()),
                  ),
                ),
              ),
              const SliderScaleLabels(labels: ['0', '15', '30 min']),
            ],
          ),
        ),
      ],
    );
  }
}

/// How hard street legs avoid inclines. Only offered by a server with
/// elevation data, which would otherwise ignore it.
class SearchOptionsInclineGroup extends StatelessWidget {
  const SearchOptionsInclineGroup({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ValueChanged<RoutingOptions> onChanged;

  static const Map<ElevationCosts, String> _choices = {
    ElevationCosts.none: 'No detours',
    ElevationCosts.low: 'Small detours',
    ElevationCosts.high: 'Large detours',
  };

  @override
  Widget build(BuildContext context) {
    return OptionsGroup(
      title: 'Hills',
      children: [
        OptionsRow(
          icon: LucideIcons.mountain,
          label: 'Avoid steep inclines',
          description: 'Trades a longer route for a flatter one.',
          below: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in _choices.entries)
                SelectableTick(
                  label: entry.value,
                  selected: options.elevationCosts == entry.key,
                  onPressed: () =>
                      onChanged(options.copyWith(elevationCosts: entry.key)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
