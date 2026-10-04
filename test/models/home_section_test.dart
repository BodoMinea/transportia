import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/home_section.dart';

HomeSectionConfig _config(HomeSection section, {required bool enabled}) =>
    HomeSectionConfig(section: section, enabled: enabled);

Map<HomeSection, bool> _enabled(List<HomeSectionConfig> configs) => {
  for (final config in configs) config.section: config.enabled,
};

void main() {
  group('encoding', () {
    test('a section survives being written and read', () {
      final config = _config(HomeSection.departures, enabled: false);

      expect(config.encode(), 'departures:0');
      final decoded = HomeSectionConfig.decode(config.encode())!;
      expect(decoded.section, HomeSection.departures);
      expect(decoded.enabled, isFalse);
    });

    test('every section round-trips, each under its own name', () {
      for (final section in HomeSection.values) {
        final decoded = HomeSectionConfig.decode(
          _config(section, enabled: true).encode(),
        )!;
        expect(decoded.section, section);
      }
    });

    test('an entry this build does not know is dropped', () {
      expect(HomeSectionConfig.decode('statistics:1'), isNull);
      expect(HomeSectionConfig.decode('recentTrips'), isNull);
      expect(HomeSectionConfig.decode('recentTrips:1:1'), isNull);
    });
  });

  group('the defaults', () {
    test('show what the card always showed, and nothing more', () {
      final enabled = _enabled(HomeSectionConfig.defaults);

      expect(enabled[HomeSection.recentTrips], isTrue);
      expect(enabled[HomeSection.departures], isTrue);
      expect(enabled[HomeSection.recentSearches], isFalse);
      expect(enabled[HomeSection.favorites], isFalse);
    });

    test('list every section once', () {
      final sections = HomeSectionConfig.defaults.map((c) => c.section);

      expect(sections.toSet(), HomeSection.values.toSet());
      expect(sections, hasLength(HomeSection.values.length));
    });

    test('keep recent trips ahead of nearby departures', () {
      final shown = [
        for (final config in HomeSectionConfig.defaults)
          if (config.enabled) config.section,
      ];

      expect(shown, [HomeSection.recentTrips, HomeSection.departures]);
    });
  });

  group('reconcile', () {
    test('the order and choices made are kept', () {
      final result = HomeSectionConfig.reconcile([
        _config(HomeSection.departures, enabled: true),
        _config(HomeSection.recentTrips, enabled: false),
        _config(HomeSection.favorites, enabled: true),
        _config(HomeSection.recentSearches, enabled: true),
      ]);

      expect(result.map((c) => c.section), [
        HomeSection.departures,
        HomeSection.recentTrips,
        HomeSection.favorites,
        HomeSection.recentSearches,
      ]);
      expect(result.map((c) => c.enabled), [true, false, true, true]);
    });

    test(
      'a list stored before the newer sections gains them, switched off',
      () {
        // What a 1.0.4 build with only trips and departures will have stored.
        final result = HomeSectionConfig.reconcile([
          _config(HomeSection.recentTrips, enabled: true),
          _config(HomeSection.departures, enabled: false),
        ]);

        expect(result.take(2).map((c) => c.section), [
          HomeSection.recentTrips,
          HomeSection.departures,
        ]);
        expect(
          result.map((c) => c.section).toSet(),
          HomeSection.values.toSet(),
        );
        final enabled = _enabled(result);
        expect(enabled[HomeSection.recentTrips], isTrue);
        expect(enabled[HomeSection.departures], isFalse);
        expect(enabled[HomeSection.favorites], isFalse);
        expect(enabled[HomeSection.recentSearches], isFalse);
      },
    );

    test('nothing stored is the defaults', () {
      expect(
        HomeSectionConfig.reconcile(const []).map((c) => c.encode()),
        HomeSectionConfig.defaults.map((c) => c.encode()),
      );
    });
  });

  group('the words', () {
    test('every section has a label and a description of its own', () {
      expect(HomeSection.values.map((s) => s.label).toSet(), hasLength(4));
      expect(
        HomeSection.values.map((s) => s.description).toSet(),
        hasLength(4),
      );
    });

    test('recent trips and recent searches are told apart', () {
      expect(HomeSection.recentTrips.label, 'Recent trips');
      expect(HomeSection.recentSearches.label, 'Recent searches');
    });
  });
}
