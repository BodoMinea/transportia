import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/providers/backend_provider.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/search_options_screen.dart';
import 'package:transportia/services/place_bias_service.dart';
import 'package:transportia/services/rental_providers_service.dart';
import 'package:transportia/services/routing_options_service.dart';
import 'package:transportia/services/server_capabilities_service.dart';
import 'package:transportia/utils/place_bias.dart';
import 'package:transportia/widgets/options/icon_controls.dart';

String _fixture(String name) =>
    File('test/fixtures/transitous/$name').readAsStringSync();

/// Serves the real captures for the two requests the screen makes.
void _serveFixtures() {
  final mapInitial = _fixture('map_initial.json');
  final groups = _fixture('rentals_groups.json');
  TransitousClient.instance = TransitousClient(
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final body = path.endsWith('/map/initial')
          ? mapInitial
          : path.endsWith('/rentals')
          ? groups
          : '{}';
      return http.Response(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<BackendProvider>(
          create: (_) => BackendProvider(),
        ),
      ],
      child: const CupertinoApp(home: SearchOptionsScreen()),
    ),
  );
  // The screen reads storage and fetches on open; let the futures run.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

Finder _field(String placeholder) => find.byWidgetPredicate(
  (w) => w is CupertinoTextField && w.placeholder == placeholder,
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    RoutingOptionsService.invalidate();
    PlaceBiasService.invalidate();
    RentalProvidersService.invalidate();
    ServerCapabilitiesService.invalidate();
    _serveFixtures();
  });
  tearDown(() => TransitousClient.instance = TransitousClient());

  testWidgets('offers only what the search screen does not', (tester) async {
    await _pump(tester);

    expect(find.text('PLACE SEARCH'), findsOne);
    expect(find.text('RENTAL PROVIDERS'), findsOne);
    expect(find.text('TRANSFERS'), findsOne);
    expect(find.text('Advanced'), findsOne);
    for (final gone in [
      'Transit modes',
      'Walking pace',
      'Maximum transfers',
      'Getting to and from transit',
      'Direct journey',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('the bias slider saves, off included', (tester) async {
    await _pump(tester);

    final slider = tester.widget<OptionSlider>(find.byType(OptionSlider).first);
    slider.onChanged(0);
    await tester.pumpAndSettle();

    expect(PlaceBias.isOff(await PlaceBiasService.load()), isTrue);
    expect(await SharedPreferencesAsync().getDouble('place_bias'), 0);
    expect(find.textContaining('Your location is not sent'), findsOne);
  });

  testWidgets('a provider is found by name and kept', (tester) async {
    await _pump(tester);

    await tester.enterText(_field('Add a provider'), 'dott berl');
    await tester.pumpAndSettle();
    expect(find.text('Dott berlin'), findsOne);

    await tester.tap(find.text('Dott berlin'));
    await tester.pumpAndSettle();

    final prefs = await RentalProvidersService.loadPrefs();
    expect([for (final g in prefs.groups) g.id], ['Dott berlin']);
    expect(prefs.limit, isTrue);
    expect(
      find.byWidgetPredicate((w) => w is ModeChip && w.label == 'Dott berlin'),
      findsOne,
    );
  });

  testWidgets('removing the last provider lifts the limit', (tester) async {
    await _pump(tester);
    await tester.enterText(_field('Add a provider'), 'dott berl');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dott berlin'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((w) => w is ModeChip && w.label == 'Dott berlin'),
    );
    await tester.pumpAndSettle();

    final prefs = await RentalProvidersService.loadPrefs();
    expect(prefs.groups, isEmpty);
    expect(prefs.limit, isFalse);
  });
}
