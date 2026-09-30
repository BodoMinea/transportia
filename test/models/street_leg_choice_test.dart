import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/street_leg_choice.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/models/transitous/enums.dart';

const _walking = StreetLegChoice(modes: [TransitMode.walk], formFactors: []);

void main() {
  test('every street mode and shared vehicle sits in exactly one section', () {
    // One the defaults editor can store but no section holds would light
    // nothing and could not be turned off here.
    final modes = [
      for (final section in StreetSection.values) ...section.modes,
    ];
    final factors = [
      for (final section in StreetSection.values) ...section.formFactors,
    ];
    expect(
      modes.toSet(),
      RoutingOptions.streetModeChoices.toSet()..remove(TransitMode.rental),
    );
    expect(modes.length, modes.toSet().length);
    expect(factors.toSet(), RentalFormFactor.values.toSet());
    expect(factors.length, factors.toSet().length);
  });

  test('a shared car is a car, not a scooter', () {
    expect(StreetSection.car.formFactors, [RentalFormFactor.car]);
    expect(
      StreetSection.shared.formFactors,
      isNot(contains(RentalFormFactor.car)),
    );
  });

  group('a section', () {
    test('is on, partly on or off', () {
      expect(_walking.stateOf(StreetSection.walk), GroupState.all);
      expect(_walking.stateOf(StreetSection.car), GroupState.none);
      final dropOff = _walking.toggleMode(TransitMode.carDropoff);
      expect(dropOff.stateOf(StreetSection.car), GroupState.some);
    });

    test('switches on whole, then off whole', () {
      final on = _walking.toggleSection(StreetSection.car);
      expect(on.stateOf(StreetSection.car), GroupState.all);
      expect(on.modes, containsAll(StreetSection.car.modes));
      expect(on.formFactors, [RentalFormFactor.car]);

      final off = on.toggleSection(StreetSection.car);
      expect(off.stateOf(StreetSection.car), GroupState.none);
      expect(off.modes, [TransitMode.walk]);
    });

    test('partly on is completed rather than cleared', () {
      final some = _walking.toggleFormFactor(RentalFormFactor.bicycle);
      final completed = some.toggleSection(StreetSection.shared);
      expect(completed.stateOf(StreetSection.shared), GroupState.all);
    });

    test('leaves the other sections as they were', () {
      final withBike = _walking.toggleMode(TransitMode.bike);
      final both = withBike.toggleSection(StreetSection.shared);
      expect(both.has(TransitMode.walk), isTrue);
      expect(both.has(TransitMode.bike), isTrue);
    });
  });

  group('rentals follow the vehicles', () {
    test('the first shared vehicle brings rentals', () {
      final next = _walking.toggleFormFactor(RentalFormFactor.scooterStanding);
      expect(next.modes, contains(TransitMode.rental));
    });

    test('the last one takes them away', () {
      final next = _walking
          .toggleFormFactor(RentalFormFactor.scooterStanding)
          .toggleFormFactor(RentalFormFactor.scooterStanding);
      expect(next.modes, isNot(contains(TransitMode.rental)));
      expect(next.formFactors, isEmpty);
    });

    test('a shared car counts as a vehicle to rent', () {
      final next = _walking.toggleFormFactor(RentalFormFactor.car);
      expect(next.modes, contains(TransitMode.rental));
      expect(next.stateOf(StreetSection.shared), GroupState.none);
    });
  });

  test('the modes keep the order the pickers read', () {
    final next = _walking
        .toggleMode(TransitMode.flex)
        .toggleMode(TransitMode.bike)
        .toggleFormFactor(RentalFormFactor.bicycle);
    expect(next.modes, [
      TransitMode.walk,
      TransitMode.bike,
      TransitMode.rental,
      TransitMode.flex,
    ]);
  });

  group('summary', () {
    test('names the sections on, as a sentence', () {
      final next = _walking
          .toggleFormFactor(RentalFormFactor.bicycle)
          .toggleMode(TransitMode.carParking);
      expect(next.summary, 'Walk, shared, car');
    });

    test('with nothing on it is still walking', () {
      const empty = StreetLegChoice(modes: [], formFactors: []);
      expect(empty.summary, 'Walk');
    });
  });
}
