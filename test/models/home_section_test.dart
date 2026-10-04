import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/home_section.dart';

void main() {
  group('encoding', () {
    test('a section survives being written and read', () {
      const config = HomeSectionConfig(
        section: HomeSection.departures,
        enabled: false,
      );

      expect(config.encode(), 'departures:0');
      final decoded = HomeSectionConfig.decode(config.encode())!;
      expect(decoded.section, HomeSection.departures);
      expect(decoded.enabled, isFalse);
    });

    test('an entry this build does not know is dropped', () {
      expect(HomeSectionConfig.decode('favorites:1'), isNull);
      expect(HomeSectionConfig.decode('recentTrips'), isNull);
    });
  });

  group('reconcile', () {
    test('the order and choices made are kept', () {
      final result = HomeSectionConfig.reconcile([
        const HomeSectionConfig(section: HomeSection.departures, enabled: true),
        const HomeSectionConfig(
          section: HomeSection.recentTrips,
          enabled: false,
        ),
      ]);

      expect(result.map((c) => c.section), [
        HomeSection.departures,
        HomeSection.recentTrips,
      ]);
      expect(result.map((c) => c.enabled), [true, false]);
    });

    test('a section added since is appended, switched on', () {
      final result = HomeSectionConfig.reconcile([
        const HomeSectionConfig(
          section: HomeSection.recentTrips,
          enabled: false,
        ),
      ]);

      expect(result.map((c) => c.section), [
        HomeSection.recentTrips,
        HomeSection.departures,
      ]);
      expect(result.last.enabled, isTrue);
    });
  });
}
