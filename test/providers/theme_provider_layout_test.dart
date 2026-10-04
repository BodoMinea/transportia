import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/home_section.dart';
import 'package:transportia/models/tab_bar_item.dart';
import 'package:transportia/providers/theme_provider.dart';

/// Literals, as a build that wrote them will have.
const String _tabBarItems = 'tab_bar_items';
const String _homeSections = 'home_sections';

Future<ThemeProvider> _loaded() async {
  final provider = ThemeProvider();
  while (!provider.isInitialized) {
    await Future<void>.delayed(Duration.zero);
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the tab bar', () {
    test('every optional tab is shown until chosen otherwise', () async {
      final provider = await _loaded();

      expect(provider.tabBarItems.every((c) => c.enabledAsTab), isTrue);
    });

    test('a stored choice is honoured', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            _tabBarItems: ['departures:0', 'savedTrips:1'],
          });

      final provider = await _loaded();

      expect(
        TabBarItemConfig.isTab(provider.tabBarItems, TabBarItem.departures),
        isFalse,
      );
      expect(
        TabBarItemConfig.isTab(provider.tabBarItems, TabBarItem.savedTrips),
        isTrue,
      );
    });

    test('a change is stored and announced', () async {
      final provider = await _loaded();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setTabBarItems([
        const TabBarItemConfig(
          item: TabBarItem.departures,
          enabledAsTab: false,
        ),
        const TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: true),
      ]);

      expect(notified, 1);
      expect(await SharedPreferencesAsync().getStringList(_tabBarItems), [
        'departures:0',
        'savedTrips:1',
      ]);
    });
  });

  group('the home screen sections', () {
    test('all are shown, in the default order, until changed', () async {
      final provider = await _loaded();

      expect(
        provider.homeSections.map((c) => c.section),
        HomeSectionConfig.defaults.map((c) => c.section),
      );
      expect(provider.homeSections.every((c) => c.enabled), isTrue);
    });

    test('a stored order and choice are honoured', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            _homeSections: ['departures:1', 'recentTrips:0'],
          });

      final provider = await _loaded();

      expect(provider.homeSections.map((c) => c.section), [
        HomeSection.departures,
        HomeSection.recentTrips,
      ]);
      expect(provider.homeSections.last.enabled, isFalse);
    });

    test('a change is stored and announced', () async {
      final provider = await _loaded();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setHomeSections([
        const HomeSectionConfig(section: HomeSection.departures, enabled: true),
        const HomeSectionConfig(
          section: HomeSection.recentTrips,
          enabled: false,
        ),
      ]);

      expect(notified, 1);
      expect(await SharedPreferencesAsync().getStringList(_homeSections), [
        'departures:1',
        'recentTrips:0',
      ]);
    });
  });
}
