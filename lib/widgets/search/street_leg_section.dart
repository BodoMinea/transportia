import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../theme/app_colors.dart';
import '../options/icon_controls.dart';
import '../options/selectable_tick.dart';

/// Which street mode a mile can use, and what each is called.
///
/// The labels say what you do rather than naming the enum: nobody asks for
/// `CAR_PARKING`, they park and ride.
const Map<TransitMode, ({IconData icon, String label})> mileModeChoices = {
  TransitMode.walk: (icon: LucideIcons.footprints, label: 'Walk'),
  TransitMode.bike: (icon: LucideIcons.bike, label: 'Bike'),
  TransitMode.rental: (icon: LucideIcons.scooter, label: 'Rental'),
  TransitMode.car: (icon: LucideIcons.car, label: 'Car'),
  TransitMode.carParking: (
    icon: LucideIcons.squareParking,
    label: 'Park & ride',
  ),
};

/// Offered behind the chevron rather than as icons: each is a real way to
/// reach a stop, but not one most journeys use.
const Map<TransitMode, String> mileModeExtras = {
  TransitMode.carDropoff: 'Drop-off',
  TransitMode.hgv: 'Lorry',
  TransitMode.odm: 'On demand',
  TransitMode.flex: 'Flexible',
};

/// The vehicles the Rental icon stands for.
///
/// The icon sets these directly rather than only switching rentals on: an icon
/// that enables other buttons and nothing else says nothing about what it did.
///
/// The same set the defaults editor gives a mile when Rental is ticked there,
/// so Rental means one thing across both screens.
const List<RentalFormFactor> kRentalIconFactors =
    RoutingOptions.defaultRentalFormFactors;

/// What each shared vehicle is called, for the rental filter.
const Map<RentalFormFactor, String> rentalFormFactorLabels = {
  RentalFormFactor.bicycle: 'Shared bike',
  RentalFormFactor.cargoBicycle: 'Shared cargo bike',
  RentalFormFactor.car: 'Shared car',
  RentalFormFactor.moped: 'Shared moped',
  RentalFormFactor.scooterStanding: 'Shared scooter',
  RentalFormFactor.scooterSeated: 'Seated scooter',
  RentalFormFactor.other: 'Other vehicle',
};

/// Every street mode in the order the picks read, icons first.
const List<TransitMode> mileModeOrder = RoutingOptions.streetModeChoices;

IconData mileModeIcon(TransitMode mode) =>
    mileModeChoices[mode]?.icon ?? LucideIcons.footprints;

String mileModeLabel(TransitMode mode) =>
    mileModeChoices[mode]?.label ?? mileModeExtras[mode] ?? 'Walk';

/// The icon standing for a whole set of modes: the rightmost one selected, as
/// the pick row reads.
///
/// Picking up a bike on the way out should change the icon; which mode was
/// chosen first should not decide it forever.
IconData mileModesIcon(List<TransitMode> modes) {
  IconData icon = LucideIcons.footprints;
  for (final mode in mileModeOrder) {
    if (modes.contains(mode)) icon = mileModeIcon(mode);
  }
  return icon;
}

/// Names the modes in pick order, so the summary and the icons agree.
String mileModesLabel(List<TransitMode> modes) {
  final names = [
    for (final mode in mileModeOrder)
      if (modes.contains(mode)) mileModeLabel(mode),
  ];
  return names.isEmpty ? 'Walk' : names.join(', ');
}

/// A budget in minutes, compact enough to sit beside a clock icon.
///
/// A raw `120` next to a clock reads as a bug when the line above says two
/// hours, so anything past an hour is shown as hours.
String budgetChipText(Duration budget) {
  final minutes = budget.inMinutes;
  if (minutes < 60) return '$minutes';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h$rest';
}

/// The same budget spelled out for the summary line.
String budgetSummaryText(Duration budget) {
  final minutes = budget.inMinutes;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest';
}

/// What a street leg may use: its modes, and which shared vehicles count.
///
/// One value rather than two callbacks, because picking a shared vehicle also
/// turns rentals on — two separate edits against the same options would have
/// the second overwrite the first.
typedef StreetLegChoice = ({
  List<TransitMode> modes,
  List<RentalFormFactor> formFactors,
});

/// Mode picks and a time budget for one of the two street legs.
class StreetLegSection extends StatelessWidget {
  const StreetLegSection({
    super.key,
    required this.modes,
    required this.budget,
    required this.maxBudget,
    required this.formFactors,
    required this.tooltips,
    required this.budgetOpen,
    required this.modesOpen,
    required this.onChanged,
    required this.onBudgetChanged,
    required this.onBudgetPressed,
    required this.onModesPressed,
    required this.limitToMyProviders,
    required this.onLimitToMyProvidersPressed,
  });

  final List<TransitMode> modes;
  final Duration budget;

  /// The server's own ceiling, so the slider cannot offer what will be
  /// clamped away.
  final Duration maxBudget;

  /// Which shared vehicles this mile's rental leg may use. Empty means this
  /// mile has no rentals — see [_applyFormFactors].
  final List<RentalFormFactor> formFactors;

  final OptionTooltipController tooltips;
  final bool budgetOpen;

  /// The rarer modes and the shared-vehicle filter, open on request.
  final bool modesOpen;

  final ValueChanged<StreetLegChoice> onChanged;
  final ValueChanged<Duration> onBudgetChanged;
  final VoidCallback onBudgetPressed;
  final VoidCallback onModesPressed;

  /// Whether rentals keep to the providers named in the settings. One
  /// setting for the whole journey, shown on both legs because it sits with
  /// the rest of the rental choices.
  final bool limitToMyProviders;
  final VoidCallback onLimitToMyProvidersPressed;

  /// Adds or removes a mode, keeping the list in pick order.
  void _toggleMode(TransitMode mode) {
    // Rental is not a mode of its own here: it is the vehicles it stands for,
    // and the mode follows them.
    if (mode == TransitMode.rental) return _toggleRentalIcon();

    final next = modes.contains(mode)
        ? [
            for (final m in modes)
              if (m != mode) m,
          ]
        : _withMode(mode);
    onChanged((modes: next, formFactors: formFactors));
  }

  List<TransitMode> _withMode(TransitMode mode) => [
    for (final m in mileModeOrder)
      if (m == mode || modes.contains(m)) m,
  ];

  /// The Rental icon is lit exactly when it has nothing left to add: it
  /// stands for [kRentalIconFactors] and for nothing else, so a lone shared
  /// bike leaves it dark and shows as a chip instead.
  bool get _rentalIconSelected =>
      kRentalIconFactors.every(formFactors.contains);

  /// Ticks the icon's three vehicles, or unticks exactly those three.
  ///
  /// Anything picked from the list beyond them survives being turned off,
  /// because it is already reported on its own as a chip.
  void _toggleRentalIcon() => _applyFormFactors(
    _rentalIconSelected
        ? [
            for (final f in formFactors)
              if (!kRentalIconFactors.contains(f)) f,
          ]
        : [...formFactors, ...kRentalIconFactors],
  );

  void _toggleFormFactor(RentalFormFactor factor) => _applyFormFactors(
    formFactors.contains(factor)
        ? [
            for (final f in formFactors)
              if (f != factor) f,
          ]
        : [...formFactors, factor],
  );

  /// Applies a new set of vehicles, and moves the rental mode with it.
  ///
  /// Rentals are exactly the vehicles picked for them: choosing the first one
  /// turns them on, dropping the last turns them off. That is what keeps the
  /// icon honest — it cannot light up over a mile that has no vehicle to
  /// rent.
  void _applyFormFactors(Iterable<RentalFormFactor> factors) {
    final next = [
      for (final factor in rentalFormFactorLabels.keys)
        if (factors.contains(factor)) factor,
    ];
    final nextModes = next.isEmpty
        ? [
            for (final m in modes)
              if (m != TransitMode.rental) m,
          ]
        : _withMode(TransitMode.rental);
    onChanged((modes: nextModes, formFactors: next));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPickRow(context),
        if (modesOpen) ...[const SizedBox(height: 12), _buildMoreList(context)],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ValueChip(
            icon: LucideIcons.clock,
            label: 'Time budget',
            value: budgetChipText(budget),
            tooltips: tooltips,
            expanded: budgetOpen,
            onPressed: onBudgetPressed,
          ),
        ),
        if (budgetOpen) ...[
          const SizedBox(height: 4),
          _BudgetSlider(
            budget: budget,
            maxBudget: maxBudget,
            onChanged: onBudgetChanged,
          ),
        ],
      ],
    );
  }

  /// The five common modes, the button that opens the rest, and a chip for
  /// anything picked from it — so the row carries the whole selection.
  Widget _buildPickRow(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in mileModeChoices.entries)
          SizedBox(
            width: 42,
            child: IconPick(
              icon: entry.value.icon,
              label: entry.value.label,
              selected: entry.key == TransitMode.rental
                  ? _rentalIconSelected
                  : modes.contains(entry.key),
              tooltips: tooltips,
              onPressed: () => _toggleMode(entry.key),
            ),
          ),
        SizedBox(
          width: 42,
          child: IconPick(
            icon: modesOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            label: 'More ways to travel',
            selected: false,
            subdued: true,
            size: 16,
            tooltips: tooltips,
            onPressed: onModesPressed,
          ),
        ),
        for (final mode in mileModeExtras.keys)
          if (modes.contains(mode))
            ModeChip(
              label: mileModeExtras[mode]!,
              onRemove: () => _toggleMode(mode),
            ),
        // Chips carry what the icons cannot say, so the ones the lit Rental
        // icon already stands for are not repeated beside it.
        for (final factor in formFactors)
          if (!(_rentalIconSelected && kRentalIconFactors.contains(factor)))
            ModeChip(
              label: rentalFormFactorLabels[factor] ?? 'Shared',
              onRemove: () => _toggleFormFactor(factor),
            ),
      ],
    );
  }

  Widget _buildMoreList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionGroupHeading('Other ways to travel'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in mileModeExtras.entries)
              SelectableTick(
                label: entry.value,
                selected: modes.contains(entry.key),
                onPressed: () => _toggleMode(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OptionGroupHeading('Shared vehicles'),
        const SizedBox(height: 6),
        Text(
          formFactors.isEmpty
              ? 'Pick a vehicle to travel part of the way by rental.'
              : 'Only the kinds picked here.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.black.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in rentalFormFactorLabels.entries)
              SelectableTick(
                label: entry.value,
                selected: formFactors.contains(entry.key),
                onPressed: () => _toggleFormFactor(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableTick(
          label: 'Limit to my providers',
          selected: limitToMyProviders,
          onPressed: onLimitToMyProvidersPressed,
        ),
      ],
    );
  }
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
