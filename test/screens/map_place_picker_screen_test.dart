import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/favourites_map_screen.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
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
          pageBuilder: (_, _, _) => screen,
        ),
      ),
    ),
  );
}

/// Points at the map, as a tap would: the map is a platform view and takes
/// no taps in a test.
Future<void> _pointAt(WidgetTester tester) async {
  tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
    const math.Point(0, 0),
    const LatLng(52.52, 13.405),
  );
  // Naming the point fails without a network and falls back to coordinates.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('picking a route end says what it is for', (tester) async {
    // It used to read "Add Favourite" whatever it was opened for.
    await _pump(
      tester,
      const MapPlacePickerScreen.pick(
        title: 'Origin',
        confirmLabel: 'Use as origin',
      ),
    );

    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('Add Favourite'), findsNothing);

    await _pointAt(tester);

    expect(find.text('Use as origin'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('keeping a favourite still says so', (tester) async {
    await _pump(tester, const MapPlacePickerScreen.favourite());

    expect(find.text('Add Favourite'), findsOneWidget);

    await _pointAt(tester);

    expect(find.text('Save'), findsOneWidget);
  });
}
