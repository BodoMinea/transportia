import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/tab_bar_item.dart';

void main() {
  group('encoding', () {
    test('an item survives being written and read', () {
      const config = TabBarItemConfig(
        item: TabBarItem.savedTrips,
        enabledAsTab: false,
      );

      expect(config.encode(), 'savedTrips:0');
      final decoded = TabBarItemConfig.decode(config.encode())!;
      expect(decoded.item, TabBarItem.savedTrips);
      expect(decoded.enabledAsTab, isFalse);
    });

    test('an entry this build does not know is dropped', () {
      expect(TabBarItemConfig.decode('statistics:1'), isNull);
      expect(TabBarItemConfig.decode('departures'), isNull);
      expect(TabBarItemConfig.decode('departures:1:1'), isNull);
    });
  });

  group('reconcile', () {
    test('what the rider chose is kept', () {
      final result = TabBarItemConfig.reconcile([
        const TabBarItemConfig(
          item: TabBarItem.departures,
          enabledAsTab: false,
        ),
        const TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: true),
      ]);

      expect(result.map((c) => c.enabledAsTab), [false, true]);
    });

    test('an item missing from storage comes back as its default', () {
      final result = TabBarItemConfig.reconcile([
        const TabBarItemConfig(
          item: TabBarItem.savedTrips,
          enabledAsTab: false,
        ),
      ]);

      expect(result.map((c) => c.item), [
        TabBarItem.savedTrips,
        TabBarItem.departures,
      ]);
      expect(result.last.enabledAsTab, isTrue);
    });

    test('empty storage is the defaults', () {
      expect(
        TabBarItemConfig.reconcile(const []).map((c) => c.item),
        TabBarItemConfig.defaults.map((c) => c.item),
      );
    });
  });

  group('isTab', () {
    test('reads the choice made', () {
      final configs = [
        const TabBarItemConfig(
          item: TabBarItem.departures,
          enabledAsTab: false,
        ),
      ];

      expect(TabBarItemConfig.isTab(configs, TabBarItem.departures), isFalse);
    });

    test('an item with no entry is a tab, as the bar always was', () {
      expect(TabBarItemConfig.isTab(const [], TabBarItem.savedTrips), isTrue);
    });
  });
}
