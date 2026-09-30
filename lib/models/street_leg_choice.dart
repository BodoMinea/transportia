import 'routing_options.dart';
import 'transit_mode_group.dart';
import 'transitous/enums.dart';

/// The ways of getting to or from a station, as the search card groups them.
///
/// A section is a set of street modes and shared vehicles switched on and off
/// together. Shared cars sit with cars rather than with the bikes and
/// scooters: what matters to a rider is what they will be driving or riding,
/// not whether it is rented.
enum StreetSection {
  walk('Walk', 'Walk', modes: [TransitMode.walk]),
  ownBike('Own bike', 'Bike', modes: [TransitMode.bike]),
  shared(
    'Shared bikes & scooters',
    'Shared',
    formFactors: [
      RentalFormFactor.bicycle,
      RentalFormFactor.cargoBicycle,
      RentalFormFactor.scooterStanding,
      RentalFormFactor.scooterSeated,
      RentalFormFactor.moped,
      RentalFormFactor.other,
    ],
  ),
  car(
    'Car',
    'Car',
    modes: [TransitMode.car, TransitMode.carParking, TransitMode.carDropoff],
    formFactors: [RentalFormFactor.car],
  ),
  other(
    'Other',
    'Other',
    modes: [TransitMode.odm, TransitMode.flex, TransitMode.hgv],
  );

  const StreetSection(
    this.title,
    this.shortLabel, {
    this.modes = const [],
    this.formFactors = const [],
  });

  /// The heading in the full view.
  final String title;

  /// Its name in the one-line summary of the leg.
  final String shortLabel;

  final List<TransitMode> modes;
  final List<RentalFormFactor> formFactors;

  int get _size => modes.length + formFactors.length;

  /// What one choice within a section is called.
  static String modeLabel(TransitMode mode) => switch (mode) {
    TransitMode.walk => 'Walk',
    TransitMode.bike => 'Bike',
    TransitMode.car => 'Drive',
    TransitMode.carParking => 'Park & ride',
    TransitMode.carDropoff => 'Drop-off',
    TransitMode.odm => 'On demand',
    TransitMode.flex => 'Flexible',
    TransitMode.hgv => 'Lorry',
    TransitMode.rental => 'Rental',
    _ => 'Walk',
  };

  static String formFactorLabel(RentalFormFactor factor) => switch (factor) {
    RentalFormFactor.bicycle => 'Bike',
    RentalFormFactor.cargoBicycle => 'Cargo bike',
    RentalFormFactor.scooterStanding => 'E-scooter',
    RentalFormFactor.scooterSeated => 'Seated scooter',
    RentalFormFactor.moped => 'Moped',
    RentalFormFactor.car => 'Shared car',
    RentalFormFactor.other => 'Other',
  };
}

/// What one street leg may use: its modes and which shared vehicles count.
///
/// One value rather than two, because the rental mode follows the vehicles —
/// picking the first shared vehicle turns rentals on, dropping the last turns
/// them off — and two separate edits would let one overwrite the other.
class StreetLegChoice {
  const StreetLegChoice({required this.modes, required this.formFactors});

  final List<TransitMode> modes;
  final List<RentalFormFactor> formFactors;

  bool has(TransitMode mode) => modes.contains(mode);
  bool rents(RentalFormFactor factor) => formFactors.contains(factor);

  GroupState stateOf(StreetSection section) => GroupState.of(
    section.modes.where(has).length + section.formFactors.where(rents).length,
    section._size,
  );

  /// Switches a whole section: off when all of it is on, otherwise all on,
  /// so a partly-on section is completed rather than cleared.
  StreetLegChoice toggleSection(StreetSection section) {
    final on = stateOf(section) != GroupState.all;
    return _with(
      modes: {
        for (final m in modes)
          if (!section.modes.contains(m)) m,
        if (on) ...section.modes,
      },
      formFactors: {
        for (final f in formFactors)
          if (!section.formFactors.contains(f)) f,
        if (on) ...section.formFactors,
      },
    );
  }

  StreetLegChoice toggleMode(TransitMode mode) => _with(
    modes: has(mode) ? ({...modes}..remove(mode)) : {...modes, mode},
    formFactors: formFactors.toSet(),
  );

  StreetLegChoice toggleFormFactor(RentalFormFactor factor) => _with(
    modes: modes.toSet(),
    formFactors: rents(factor)
        ? ({...formFactors}..remove(factor))
        : {...formFactors, factor},
  );

  /// Puts both lists in their canonical order and moves the rental mode with
  /// the vehicles: rentals are exactly the vehicles picked for them.
  static StreetLegChoice _with({
    required Set<TransitMode> modes,
    required Set<RentalFormFactor> formFactors,
  }) {
    final renting = formFactors.isNotEmpty;
    return StreetLegChoice(
      modes: [
        for (final m in RoutingOptions.streetModeChoices)
          if (m == TransitMode.rental ? renting : modes.contains(m)) m,
      ],
      formFactors: [
        for (final f in RentalFormFactor.values)
          if (formFactors.contains(f)) f,
      ],
    );
  }

  /// The sections that are at least partly on, in card order.
  List<StreetSection> get sectionsOn => [
    for (final section in StreetSection.values)
      if (stateOf(section) != GroupState.none) section,
  ];

  /// The leg in a line, as the collapsed stage shows it.
  String get summary {
    final on = sectionsOn;
    if (on.isEmpty) return StreetSection.walk.shortLabel;
    // A list in a sentence: only its first word is capitalised.
    return [
      on.first.shortLabel,
      for (final section in on.skip(1)) section.shortLabel.toLowerCase(),
    ].join(', ');
  }
}
