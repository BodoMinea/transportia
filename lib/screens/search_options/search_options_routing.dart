import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../models/transitous/server_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/options/option_rows.dart';
import '../../widgets/options/value_controls.dart';

/// How transfers are walked, and how much slack each one gets.
class SearchOptionsTransfersCard extends StatelessWidget {
  const SearchOptionsTransfersCard({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  static const List<int> _bufferPresets = [0, 3, 5, 10];

  @override
  Widget build(BuildContext context) {
    final minutes = options.additionalTransferTime.inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Transfers'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A server without street routing cannot route transfers, so
              // offering the switch would be misleading.
              if (capabilities.hasRoutedTransfers) ...[
                OptionToggleRow(
                  icon: LucideIcons.footprints,
                  label: 'Use routed transfers',
                  description:
                      'Walk transfers along real paths instead of the '
                      'timetable’s fixed times.',
                  value: options.useRoutedTransfers,
                  onChanged: (value) =>
                      onChanged(options.copyWith(useRoutedTransfers: value)),
                  isLast: true,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    LucideIcons.clock4,
                    size: 18,
                    color: AppColors.accentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    minutes == 0 ? 'No extra time' : '$minutes minute buffer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _bufferPresets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: QuickValueCard(
                        value: '${_bufferPresets[i]} min',
                        selected: minutes == _bufferPresets[i],
                        onTap: () => onChanged(
                          options.copyWith(
                            additionalTransferTime: Duration(
                              minutes: _bufferPresets[i],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              StepperSelector(
                value: minutes.toDouble(),
                minValue: 0,
                maxValue: 30,
                step: 1,
                label: 'min',
                displayBuilder: (value) => value.round().toString(),
                onChanged: (value) => onChanged(
                  options.copyWith(
                    additionalTransferTime: Duration(minutes: value.round()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether to offer a journey with no transit at all, and how long it may
/// take.
class SearchOptionsDirectJourneyCard extends StatelessWidget {
  const SearchOptionsDirectJourneyCard({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ServerConfig capabilities;
  final ValueChanged<RoutingOptions> onChanged;

  static const List<int> _budgetChoices = [5, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    // The server clamps anything above its own limit, so offering larger
    // values would just be a lie about what will happen.
    final choices = _budgetChoices
        .where((m) => Duration(minutes: m) <= capabilities.maxDirectTime)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Direct journey'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offer a route with no transit when it is short enough.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              ModeChoiceRow(
                modes: RoutingOptions.streetModeChoices,
                selected: options.directModes,
                onChanged: (modes) =>
                    onChanged(options.copyWith(directModes: modes)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < choices.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: QuickValueCard(
                        value: '${choices[i]} min',
                        selected: options.maxDirectTime.inMinutes == choices[i],
                        onTap: () => onChanged(
                          options.copyWith(
                            maxDirectTime: Duration(minutes: choices[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// How hard street legs avoid inclines. Only offered by a server with
/// elevation data, which would otherwise ignore it.
class SearchOptionsInclineCard extends StatelessWidget {
  const SearchOptionsInclineCard({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Avoid steep inclines'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trades a longer route for a flatter one.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final entry in _choices.entries) ...[
                    if (entry.key != ElevationCosts.none)
                      const SizedBox(width: 8),
                    Expanded(
                      child: QuickValueCard(
                        value: entry.value,
                        selected: options.elevationCosts == entry.key,
                        onTap: () => onChanged(
                          options.copyWith(elevationCosts: entry.key),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
