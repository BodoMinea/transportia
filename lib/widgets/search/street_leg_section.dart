import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/street_leg_choice.dart';
import '../options/icon_controls.dart';
import 'leg_panel.dart';

/// Each section's mark. The scooter stands for every light shared vehicle,
/// bikes included; a shared car is a car.
const Map<StreetSection, IconData> streetSectionIcons = {
  StreetSection.walk: LucideIcons.footprints,
  StreetSection.ownBike: LucideIcons.bike,
  StreetSection.shared: LucideIcons.scooter,
  StreetSection.car: LucideIcons.car,
  StreetSection.other: LucideIcons.shapes,
};

/// The icon standing for a whole leg: the last section that is on, as the
/// row reads — picking up a bike on the way out should change it; which was
/// chosen first should not decide it forever.
IconData streetLegIcon(StreetLegChoice choice) {
  final on = choice.sectionsOn;
  return on.isEmpty
      ? streetSectionIcons[StreetSection.walk]!
      : streetSectionIcons[on.last]!;
}

/// A budget spelled out: minutes below an hour, hours past it.
///
/// A raw `120` next to a clock reads as a bug when the line above says two
/// hours.
String budgetSummaryText(Duration budget) {
  final minutes = budget.inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest';
}

/// One street leg — to the station or from it — as sections and a budget.
class StreetLegSection extends StatelessWidget {
  const StreetLegSection({
    super.key,
    required this.choice,
    required this.budget,
    required this.maxBudget,
    required this.expanded,
    required this.onExpandedChanged,
    required this.tooltips,
    required this.onChanged,
    required this.onBudgetChanged,
    required this.limitToMyProviders,
    required this.onLimitToMyProvidersPressed,
  });

  final StreetLegChoice choice;
  final Duration budget;

  /// The server's own ceiling, so the slider cannot offer what will be
  /// clamped away.
  final Duration maxBudget;

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final OptionTooltipController tooltips;
  final ValueChanged<StreetLegChoice> onChanged;
  final ValueChanged<Duration> onBudgetChanged;

  /// Whether rentals keep to the providers named in the settings. One
  /// setting for the whole journey, shown on both legs because it sits with
  /// the rest of the rental choices.
  final bool limitToMyProviders;
  final VoidCallback onLimitToMyProvidersPressed;

  @override
  Widget build(BuildContext context) {
    return LegPanel(
      tooltips: tooltips,
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      sections: [for (final section in StreetSection.values) _section(section)],
      options: [
        LegOption.value(
          icon: LucideIcons.clock,
          title: 'Time budget',
          value: budgetSummaryText(budget),
          slider: _BudgetSlider(
            budget: budget,
            maxBudget: maxBudget,
            onChanged: onBudgetChanged,
          ),
        ),
      ],
    );
  }

  LegSection _section(StreetSection section) => LegSection(
    mark: Icon(streetSectionIcons[section]),
    title: section.title,
    state: choice.stateOf(section),
    onToggle: () => onChanged(choice.toggleSection(section)),
    // A section that is one mode has nothing to choose between.
    choices: section.modes.length + section.formFactors.length < 2
        ? const []
        : [
            for (final mode in section.modes)
              LegChoice(
                label: StreetSection.modeLabel(mode),
                selected: choice.has(mode),
                onPressed: () => onChanged(choice.toggleMode(mode)),
              ),
            for (final factor in section.formFactors)
              LegChoice(
                label: StreetSection.formFactorLabel(factor),
                selected: choice.rents(factor),
                onPressed: () => onChanged(choice.toggleFormFactor(factor)),
              ),
            // Last and apart from the vehicles: which providers, not which
            // kind. Switching the section leaves it as it is.
            if (section == StreetSection.shared)
              LegChoice(
                label: 'Only my providers',
                selected: limitToMyProviders,
                onPressed: onLimitToMyProvidersPressed,
              ),
          ],
  );
}

class _BudgetSlider extends StatelessWidget {
  const _BudgetSlider({
    required this.budget,
    required this.maxBudget,
    required this.onChanged,
  });

  final Duration budget;
  final Duration maxBudget;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = maxBudget.inMinutes.toDouble();
    final step = RoutingOptions.mileBudgetStep.inMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionSlider(
          value: budget.inMinutes.toDouble().clamp(0, maxMinutes),
          max: maxMinutes,
          divisions: (maxMinutes / step).round(),
          semanticLabel: 'Minutes',
          onChanged: (value) =>
              onChanged(Duration(minutes: (value / step).round() * step)),
        ),
        SliderScaleLabels(
          labels: [
            '0',
            budgetSummaryText(maxBudget ~/ 2),
            budgetSummaryText(maxBudget),
          ],
        ),
      ],
    );
  }
}
