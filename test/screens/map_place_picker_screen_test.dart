import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/transitous/match.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/map_place_picker/edge_tabs.dart';
import 'package:transportia/screens/map_place_picker/map_place_picker_screen.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

/// Pushes [screen] over a home route and hands back what it pops with.
Future<List<Object?>> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final popped = <Object?>[];
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
          pageBuilder: (context, _, _) => _Opener(
            onOpen: () async {
              popped.add(
                await Navigator.of(context).push<Object?>(
                  PageRouteBuilder(pageBuilder: (_, _, _) => screen),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return popped;
}

class _Opener extends StatelessWidget {
  const _Opener({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onOpen, child: const Text('open'));
}

/// Taps the map, as a finger would: the map is a platform view and takes
/// no taps in a test.
Future<void> _tapMap(WidgetTester tester, LatLng at) async {
  tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
    const math.Point(0, 0),
    at,
  );
  // Naming the point fails without a network and falls back to coordinates.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump();
}

List<TransitousLocationSuggestion> _paris() => [
  for (final m
      in jsonDecode(
            File(
              'test/fixtures/transitous/geocode_paris.json',
            ).readAsStringSync(),
          )
          as List)
    TransitousLocationSuggestion.fromMatch(
      Match.fromJson(m as Map<String, dynamic>),
    ),
];

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
        title: 'Select Origin',
        confirmLabel: 'Select',
      ),
    );

    expect(find.text('Select Origin'), findsOneWidget);
    expect(find.text('Add Favourite'), findsNothing);

    await _tapMap(tester, const LatLng(52.52, 13.405));

    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('keeping a favourite still says so', (tester) async {
    await _pump(tester, const MapPlacePickerScreen.favourite());

    expect(find.text('Add Favourite'), findsOneWidget);

    await _tapMap(tester, const LatLng(52.52, 13.405));

    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('a picked point comes back as a place at that point', (
    tester,
  ) async {
    final popped = await _pump(
      tester,
      const MapPlacePickerScreen.pick(
        title: 'Select Origin',
        confirmLabel: 'Select',
      ),
    );

    await _tapMap(tester, const LatLng(52.52, 13.405));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    final place = popped.single! as TransitousLocationSuggestion;
    expect(place.lat, closeTo(52.52, 1e-9));
    expect(place.lon, closeTo(13.405, 1e-9));
    expect(place.type, 'PLACE');
    expect(place.stopId, isNull);
  });

  group('with results', () {
    testWidgets('opens framed on the search, not on the rider', (tester) async {
      await _pump(
        tester,
        MapPlacePickerScreen.pick(
          title: 'Results for “Paris”',
          confirmLabel: 'Select',
          results: _paris(),
        ),
      );

      final camera = tester
          .widget<MapLibreMap>(find.byType(MapLibreMap))
          .initialCameraPosition;
      // Paris, France: the city and its two stations.
      expect(camera.target.latitude, closeTo(48.86, 0.1));
      expect(camera.target.longitude, closeTo(2.35, 0.1));
      // Close enough to tell the stations apart, not a street.
      expect(camera.zoom, inInclusiveRange(11, 12));
      expect(
        find.text('Tap a result for details, or anywhere to pick that point'),
        findsOne,
      );
    });

    testWidgets('points at the results off screen', (tester) async {
      await _pump(
        tester,
        MapPlacePickerScreen.pick(
          title: 'Results for “Paris”',
          confirmLabel: 'Select',
          results: _paris(),
        ),
      );

      final tabs = tester.widgetList<EdgeTab>(find.byType(EdgeTab)).toList();
      expect(tabs, isNotEmpty);
      // Eight towns in the US lie one way: one tab, stacked.
      expect(tabs.where((t) => t.several), isNotEmpty);
    });

    testWidgets('a timetable picks results, never a bare point', (
      tester,
    ) async {
      await _pump(
        tester,
        MapPlacePickerScreen.pick(
          title: 'Results for “Paris”',
          confirmLabel: 'Select',
          results: _paris(),
          allowsPoint: false,
        ),
      );

      expect(find.text('Tap a result for details'), findsOne);
      await _tapMap(tester, const LatLng(48.9, 2.4));

      expect(find.text('Selected Location'), findsNothing);
      expect(find.text('Select'), findsNothing);
    });
  });
}
