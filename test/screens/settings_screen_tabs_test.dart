import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/tab_bar_item.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/settings_screen.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<TabBarItemConfig> tabBarItems,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Storage is real async work, so it happens outside the fake clock.
  final provider = (await tester.runAsync(() async {
    final provider = ThemeProvider();
    while (!provider.isInitialized) {
      await Future<void>.delayed(Duration.zero);
    }
    await provider.setTabBarItems(tabBarItems);
    return provider;
  }))!;

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: provider,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: Size(900, 1600)),
          child: SettingsScreen(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('with every screen a tab there is nothing to link to', (
    tester,
  ) async {
    await _pump(tester, tabBarItems: TabBarItemConfig.defaults);

    expect(find.text('Screens'), findsNothing);
    expect(find.text('Departures'), findsNothing);
    expect(find.text('Saved trips'), findsNothing);
  });

  testWidgets('a screen taken off the tab bar is offered here instead', (
    tester,
  ) async {
    await _pump(
      tester,
      tabBarItems: const [
        TabBarItemConfig(item: TabBarItem.departures, enabledAsTab: true),
        TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: false),
      ],
    );

    expect(find.text('Screens'), findsOneWidget);
    expect(find.text('Saved trips'), findsOneWidget);
    expect(find.text('Departures'), findsNothing);
  });

  testWidgets('both can be offered at once', (tester) async {
    await _pump(
      tester,
      tabBarItems: const [
        TabBarItemConfig(item: TabBarItem.departures, enabledAsTab: false),
        TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: false),
      ],
    );

    expect(find.text('Departures'), findsOneWidget);
    expect(find.text('Saved trips'), findsOneWidget);
  });
}
