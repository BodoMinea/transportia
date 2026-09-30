import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transit_mode_group.dart';
import '../../models/transitous/enums.dart';
import '../options/icon_controls.dart';
import 'leg_panel.dart';

/// The icon each transport group shows.
const Map<TransitModeGroup, IconData> _groupIcons = {
  TransitModeGroup.rail: LucideIcons.trainFront,
  TransitModeGroup.metro: LucideIcons.trainFrontTunnel,
  TransitModeGroup.bus: LucideIcons.bus,
  TransitModeGroup.boat: LucideIcons.ship,
};

/// The modes no group covers, as a section of their own so every mode has a
/// switch on the compact row.
const IconData _otherIcon = LucideIcons.shapes;

/// The ride: which transport it may use, and the settings that belong to the
/// vehicle rather than to either street leg.
class TransitSection extends StatelessWidget {
  const TransitSection({
    super.key,
    required this.options,
    required this.expanded,
    required this.onExpandedChanged,
    required this.tooltips,
    required this.onChanged,
    required this.onViaPressed,
  });

  final RoutingOptions options;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final OptionTooltipController tooltips;
  final ValueChanged<RoutingOptions> onChanged;
  final VoidCallback onViaPressed;

  TransitSelection get _selection => options.transitSelection;

  void _select(TransitSelection next) =>
      onChanged(options.withTransitSelection(next));

  @override
  Widget build(BuildContext context) {
    return LegPanel(
      tooltips: tooltips,
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      sections: [
        for (final group in TransitModeGroup.values)
          _section(
            icon: _groupIcons[group]!,
            title: group.label,
            modes: group.modes,
          ),
        _section(
          icon: _otherIcon,
          title: 'Other',
          modes: TransitModeGroup.extras,
        ),
      ],
      options: _options(),
    );
  }

  LegSection _section({
    required IconData icon,
    required String title,
    required List<TransitMode> modes,
  }) => LegSection(
    mark: Icon(icon),
    title: title,
    state: _selection.stateOfModes(modes),
    onToggle: () => _select(_selection.toggleModes(modes)),
    choices: [
      for (final mode in modes)
        LegChoice(
          label: TransitModeGroup.modeLabel(mode),
          selected: _selection.has(mode),
          onPressed: () => _select(_selection.toggleMode(mode)),
        ),
    ],
  );

  List<LegOption> _options() => [
    LegOption.toggle(
      mark: const RegionalGlyph(),
      title: 'Regional only',
      on: _selection.isRegionalOnly,
      onToggle: () => _select(_selection.toggleRegionalOnly()),
    ),
    LegOption.value(
      icon: LucideIcons.waypoints,
      title: 'Maximum changes',
      value: options.maxTransfers?.toString(),
      slider: _ChangesSlider(options: options, onChanged: onChanged),
    ),
    // Always offered, and already on when the same vehicle is at both ends —
    // that is when it is travelling with you rather than being left at the
    // station. The derivation is a starting point, not a gate: turning it
    // off there, or on elsewhere, is a real request.
    LegOption.toggle(
      mark: const Icon(LucideIcons.bike),
      title: 'Bike on board',
      on: options.requireBikeTransport,
      onToggle: () => onChanged(
        options.copyWith(bikeCarriageOverride: !options.requireBikeTransport),
      ),
    ),
    LegOption.toggle(
      mark: const Icon(LucideIcons.car),
      title: 'Car on board',
      on: options.requireCarTransport,
      onToggle: () => onChanged(
        options.copyWith(carCarriageOverride: !options.requireCarTransport),
      ),
    ),
    LegOption.toggle(
      mark: const Icon(LucideIcons.ticketX),
      title: 'No reservation needed',
      on: options.noCompulsoryReservation,
      onToggle: () => onChanged(
        options.copyWith(
          noCompulsoryReservation: !options.noCompulsoryReservation,
        ),
      ),
    ),
    // An action — it opens the stop picker — so not on the compact row of
    // switches.
    LegOption.toggle(
      mark: const Icon(LucideIcons.mapPin),
      title: options.via.isEmpty
          ? 'Travel through a stop'
          : 'Travelling through ${options.via.length} '
                '${options.via.length == 1 ? "stop" : "stops"}',
      on: options.via.isNotEmpty,
      onToggle: onViaPressed,
      inCompactRow: false,
    ),
  ];
}

class _ChangesSlider extends StatelessWidget {
  const _ChangesSlider({required this.options, required this.onChanged});

  final RoutingOptions options;
  final ValueChanged<RoutingOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionSlider(
          value: options.transfersSliderValue.toDouble(),
          max: RoutingOptions.unlimitedTransfersSliderValue.toDouble(),
          divisions: RoutingOptions.unlimitedTransfersSliderValue,
          semanticLabel: 'Maximum changes',
          onChanged: (value) =>
              onChanged(options.withTransfersSliderValue(value.round())),
        ),
        SliderScaleLabels(
          labels: ['0', '${RoutingOptions.maxTransferChoice}', '∞'],
        ),
      ],
    );
  }
}
