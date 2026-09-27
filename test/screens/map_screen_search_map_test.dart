import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/map_screen.dart';
import 'package:transportia/widgets/map/bottom_sheet_chrome.dart';
import 'package:transportia/widgets/route_bottom_card.dart';

/// Literal, as a released build will have written it.
const String _searchMapEnabled = 'search_map_enabled';

Future<void> _pumpSearchScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: WidgetsApp(
        color: const Color(0xFF000000),
        localizationsDelegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          // Deferred, so the screen does not ask for the location on its own.
          pageBuilder: (_, _, _) => const MapScreen(deferInit: true),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('with the map turned off, none is ever built', (tester) async {
    // Building the map is what downloads tiles and starts polling vehicles:
    // everything the map fetches is started from its own callbacks.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({_searchMapEnabled: false});

    await _pumpSearchScreen(tester);
    expect(find.byType(MapLibreMap), findsNothing);

    // Once the setting has been read, and the screen has settled.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(MapLibreMap), findsNothing);
    expect(find.byType(BottomCard), findsOneWidget);
    expect(
      find.byType(BottomSheetHandle),
      findsNothing,
      reason: 'the card is the page, not a sheet over nothing',
    );
  });

  testWidgets('no map is built before the setting has been read', (
    tester,
  ) async {
    // Stored as on, but the first frame cannot know that yet — and a rider
    // who had turned it off must not pay for a map on every launch.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({_searchMapEnabled: true});

    await _pumpSearchScreen(tester);

    expect(find.byType(MapLibreMap), findsNothing);
    expect(find.byType(BottomCard), findsOneWidget);
  });
}
