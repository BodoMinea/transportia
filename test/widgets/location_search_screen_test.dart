import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/models/my_location.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/screens/favourites_map_screen.dart';
import 'package:transportia/screens/location_search_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/models/saved_place.dart';
import 'package:transportia/services/saved_places_service.dart';
import 'package:transportia/utils/place_icons.dart';

FavoritePlace _favourite({
  required String id,
  required String name,
  String? label,
  String type = 'STOP',
  double lat = 52.5,
  double lon = 13.4,
  // A stop is only offered when its feed id is known, so the default fixture
  // carries one; pass null to model a favourite kept before ids were stored.
  String? stopId = 'de-DELFI_de:11000:900100003',
  String iconName = FavoritePlace.defaultIconName,
}) => FavoritePlace(
  id: id,
  name: name,
  label: label,
  type: type,
  stopId: type.toUpperCase() == 'STOP' ? stopId : null,
  lat: lat,
  lon: lon,
  iconName: iconName,
  addedAt: DateTime.utc(2026, 1, 1),
);

/// Keeps [favourites] in the order given.
Future<void> _keep(List<FavoritePlace> favourites) async {
  for (final favourite in favourites) {
    await FavoritesService.saveFavorite(favourite);
  }
  await FavoritesService.reorderFavorites(favourites);
}

SavedPlace _recent(
  String name, {
  String type = 'STOP',
  double lat = 52.5,
  double lon = 13.46,
  List<TransitMode> modes = const [],
}) => SavedPlace(
  name: name,
  type: type,
  lat: lat,
  lon: lon,
  stopId: type == 'STOP' ? 'de-DELFI_$name' : null,
  importance: SavedPlacesService.initialImportance,
  modes: modes,
);

Future<void> _remember(SavedPlacesBucket bucket, List<SavedPlace> places) =>
    SavedPlacesService.savePlaces(bucket: bucket, places: places);

List<String> _storedOrder() => [
  for (final f in FavoritesService.favoritesListenable.value) f.id,
];

/// Holds a favourite still until it lifts to be dragged; [past] more keeps it
/// still after that.
Future<TestGesture> _press(
  WidgetTester tester,
  String text, {
  Duration past = Duration.zero,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(text)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  if (past > Duration.zero) await tester.pump(past);
  return gesture;
}

/// Lifts a favourite and drags it [dy] down, in steps, as a finger would.
Future<void> _drag(WidgetTester tester, String text, double dy) async {
  final gesture = await _press(tester, text);
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  bool showMyLocation = false,
  String? type,
  SavedPlacesBucket bucket = SavedPlacesBucket.search,
  LatLng? placeBias,
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Pushed as a route rather than handed to WidgetsApp's builder, which sits
  // outside the Navigator: the screen focuses its field on open, and an
  // EditableText needs an Overlay to put its selection handles in.
  await tester.pumpWidget(
    // The map picker this screen opens reads the map style from it.
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: WidgetsApp(
        color: const Color(0xFF000000),
        // The same delegates app.dart installs; showCupertinoDialog wants
        // CupertinoLocalizations for its barrier label.
        localizationsDelegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => LocationSearchScreen(
            title: 'Destination',
            bucket: bucket,
            type: type,
            showMyLocation: showMyLocation,
            placeBias: placeBias,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FavoritesService.favoritesListenable.value = const [];
  });

  testWidgets('favourites are there before a single character is typed', (
    tester,
  ) async {
    // The moment you want a favourite is when the field is empty; the old
    // dropdown deliberately withheld them until you started typing.
    await _keep([
      _favourite(id: 'a', name: 'Hauptbahnhof', label: 'Home'),
      _favourite(id: 'b', name: 'Alexanderplatz', lat: 52.52, lon: 13.41),
    ]);

    await _pump(tester);

    expect(find.text('FAVOURITES'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('a renamed place shows both names, an unrenamed one shows one', (
    tester,
  ) async {
    await _keep([
      _favourite(id: 'a', name: 'Hauptbahnhof', label: 'Home'),
      _favourite(id: 'b', name: 'Alexanderplatz', lat: 52.52, lon: 13.41),
    ]);

    await _pump(tester);

    // The alias leads, the searched name sits under it.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Hauptbahnhof'), findsOneWidget);
    // Nothing renamed here, so the name is not printed twice.
    expect(find.text('Alexanderplatz'), findsOneWidget);
  });

  testWidgets('an empty list says how to fill it', (tester) async {
    await _pump(tester);
    expect(find.text('Tap the heart on a place to keep it here.'), findsOne);
  });

  testWidgets('the map is offered as a way to answer', (tester) async {
    // Some places are easier to point at than to name.
    await _pump(tester);
    expect(find.bySemanticsLabel('Pick a point on the map'), findsOne);
  });

  testWidgets('the map picker is headed and confirmed for this search', (
    tester,
  ) async {
    // It used to open as "Add Favourite" with a "Save" button, whatever the
    // search was for.
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Pick a point on the map'));
    await tester.pumpAndSettle();

    final picker = tester.widget<MapPlacePickerScreen>(
      find.byType(MapPlacePickerScreen),
    );
    expect(picker.title, 'Select Destination');
    expect(picker.confirmLabel, 'Select');
    expect(find.text('Add Favourite'), findsNothing);
  });

  testWidgets('the map sits in the search field, as its one icon', (
    tester,
  ) async {
    // It used to be a boxed button beside the field; the search screen's own
    // map button went, so this is the one way left to point at a place.
    await _pump(tester);

    final field = find.byType(CupertinoTextField);
    expect(
      find.descendant(of: field, matching: find.byIcon(LucideIcons.mapPlus)),
      findsOne,
    );
    expect(find.byIcon(LucideIcons.mapPlus), findsOne);
  });

  testWidgets('clearing the query sits beside the map, not instead of it', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(CupertinoTextField), 'Al');
    await tester.pump();

    expect(find.byIcon(LucideIcons.x), findsOne);
    expect(find.bySemanticsLabel('Pick a point on the map'), findsOne);
  });

  testWidgets('a favourite offers its actions from the dots and a long hold', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Edit Hauptbahnhof'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Favourite'), findsOne);
    expect(find.text('Remove favourite'), findsOne);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Favourite'), findsNothing);

    // A long press lifts it to drag; held still past that, the menu opens.
    final gesture = await _press(
      tester,
      'Hauptbahnhof',
      past: const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit Favourite'), findsOne);
    await gesture.up();
  });

  testWidgets('renaming writes the alias and leaves the name alone', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Edit Hauptbahnhof'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = FavoritesService.favoritesListenable.value.single;
    expect(stored.label, 'Home');
    expect(stored.name, 'Hauptbahnhof');
    expect(stored.displayName, 'Home');
  });

  testWidgets('renaming a stop kept with its transport icon keeps the icon', (
    tester,
  ) async {
    // The picker does not offer the transport icons, so nothing in it is
    // selected; saving a new name must not take that as a pick.
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof', iconName: 'train')]);
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Edit Hauptbahnhof'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Work');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = FavoritesService.favoritesListenable.value.single;
    expect(stored.label, 'Work');
    expect(stored.iconName, 'train');
    expect(find.byIcon(LucideIcons.trainFront), findsOne);
  });

  testWidgets('My Location leads the list when it can answer', (tester) async {
    // Where you are is the commonest origin, and it is the one answer the
    // list can give without a search.
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester, showMyLocation: true);

    expect(find.text(myLocationName), findsOneWidget);

    final myLocation = tester.getRect(find.text(myLocationName));
    final favourite = tester.getRect(find.text('Hauptbahnhof'));
    expect(myLocation.top, lessThan(favourite.top));
  });

  testWidgets('a stop search does not offer it', (tester) async {
    // A coordinate is not a stop, so it could not answer a timetable.
    await _pump(tester);
    expect(find.text(myLocationName), findsNothing);
  });

  group('a stop search offers only stops', () {
    Future<void> keepBoth() async {
      await _keep([
        _favourite(id: 'a', name: 'Hauptbahnhof'),
        _favourite(
          id: 'b',
          name: 'Chausseestraße 12',
          type: 'ADDRESS',
          lat: 52.53,
          lon: 13.38,
        ),
      ]);
      await SavedPlacesService.savePlaces(
        bucket: SavedPlacesBucket.timetable,
        places: [
          SavedPlace(
            name: 'Ostkreuz',
            type: 'STOP',
            lat: 52.5,
            lon: 13.46,
            stopId: 'de-DELFI_de:11000:900120005',
            importance: SavedPlacesService.initialImportance,
          ),
          SavedPlace(
            name: 'Museumsinsel 2',
            type: 'ADDRESS',
            lat: 52.52,
            lon: 13.4,
            importance: SavedPlacesService.initialImportance,
          ),
        ],
      );
    }

    testWidgets('a favourite that is not a stop is left out', (tester) async {
      // Picking it could not answer a departure board, so offering it is a
      // dead end.
      await keepBoth();
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      expect(find.text('Hauptbahnhof'), findsOneWidget);
      expect(find.text('Chausseestraße 12'), findsNothing);
    });

    testWidgets('a recent that is not a stop is left out', (tester) async {
      await keepBoth();
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      expect(find.text('Ostkreuz'), findsOneWidget);
      expect(find.text('Museumsinsel 2'), findsNothing);
    });

    testWidgets('a route search still offers everything', (tester) async {
      // No type, so nothing is filtered — this is the picker the map screen
      // opens, where an address is a perfectly good answer.
      await _keep([
        _favourite(id: 'b', name: 'Chausseestraße 12', type: 'ADDRESS'),
      ]);
      await _pump(tester);

      expect(find.text('Chausseestraße 12'), findsOneWidget);
    });

    testWidgets('with no stop among the favourites it says so', (tester) async {
      await _keep([
        _favourite(id: 'b', name: 'Chausseestraße 12', type: 'ADDRESS'),
      ]);
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      expect(find.text('None of your favourites is a stop.'), findsOne);
    });
  });

  group('keeping a place from the lists', () {
    testWidgets('the heart on a recent keeps it without picking it', (
      tester,
    ) async {
      await _remember(SavedPlacesBucket.search, [
        _recent('Ostkreuz', modes: const [TransitMode.suburban]),
      ]);
      await _pump(tester);

      await tester.tap(find.bySemanticsLabel('Keep Ostkreuz'));
      await tester.pumpAndSettle();

      final kept = FavoritesService.favoritesListenable.value.single;
      expect(kept.name, 'Ostkreuz');
      expect(kept.stopId, 'de-DELFI_Ostkreuz');
      // Kept with the face the list drew it with.
      expect(kept.iconName, 'train');
      // Still here, not popped with an answer.
      expect(find.byType(LocationSearchScreen), findsOne);
    });

    testWidgets('a kept place moves up and is listed once', (tester) async {
      await _remember(SavedPlacesBucket.search, [_recent('Ostkreuz')]);
      await _pump(tester);
      expect(find.text('RECENT'), findsOne);

      await tester.tap(find.bySemanticsLabel('Keep Ostkreuz'));
      await tester.pumpAndSettle();

      expect(find.text('Ostkreuz'), findsOne);
      expect(find.text('RECENT'), findsNothing);
      final favouritesHeading = tester.getRect(find.text('FAVOURITES'));
      expect(
        tester.getRect(find.text('Ostkreuz')).top,
        greaterThan(favouritesHeading.top),
      );
    });

    testWidgets('letting a favourite go puts the recent back', (tester) async {
      await _remember(SavedPlacesBucket.search, [_recent('Ostkreuz')]);
      await _keep([_favourite(id: 'a', name: 'Ostkreuz', lon: 13.46)]);
      await _pump(tester);
      expect(find.text('RECENT'), findsNothing);

      await FavoritesService.removeFavorite('a');
      await tester.pumpAndSettle();

      expect(find.text('RECENT'), findsOne);
      expect(find.bySemanticsLabel('Keep Ostkreuz'), findsOne);
    });

    testWidgets('a place that is not a stop is kept with the pin', (
      tester,
    ) async {
      await _remember(SavedPlacesBucket.search, [
        _recent('Oranienstraße 25', type: 'ADDRESS'),
      ]);
      await _pump(tester);

      await tester.tap(find.bySemanticsLabel('Keep Oranienstraße 25'));
      await tester.pumpAndSettle();

      final kept = FavoritesService.favoritesListenable.value.single;
      expect(kept.type, 'ADDRESS');
      expect(kept.iconName, FavoritePlace.defaultIconName);
    });

    testWidgets('My Location has no heart', (tester) async {
      // Where you are moves; it is not a place to keep.
      await _pump(tester, showMyLocation: true);
      expect(find.bySemanticsLabel(RegExp('^Keep')), findsNothing);
    });

    group('from the search results', () {
      setUp(() {
        TransitousClient.instance = TransitousClient(
          httpClient: MockClient(
            (_) async => http.Response(
              File('test/fixtures/transitous/geocode.json').readAsStringSync(),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
      });
      tearDown(() => TransitousClient.instance = TransitousClient());

      Future<void> search(WidgetTester tester) async {
        await tester.enterText(find.byType(EditableText), 'Alexanderplatz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      }

      testWidgets('a kept result reads kept, and letting it go empties it', (
        tester,
      ) async {
        // The coordinates the geocoder answers S+U Alexanderplatz with.
        await _keep([
          _favourite(
            id: 'a',
            name: 'S+U Alexanderplatz Bhf (Berlin)',
            lat: 52.521510000000006,
            lon: 13.411266999999999,
          ),
        ]);
        await _pump(tester);
        await search(tester);

        const name = 'S+U Alexanderplatz Bhf (Berlin)';
        expect(find.bySemanticsLabel('Remove $name from favourites'), findsOne);

        await tester.tap(find.bySemanticsLabel('Remove $name from favourites'));
        await tester.pumpAndSettle();

        expect(FavoritesService.favoritesListenable.value, isEmpty);
        expect(find.bySemanticsLabel('Keep $name'), findsOne);
      });

      testWidgets('results say how far, where, and which country abroad', (
        tester,
      ) async {
        // A phone set to Germany, standing near Alexanderplatz.
        tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await _pump(tester, placeBias: const LatLng(52.52, 13.405));
        await search(tester);

        // Berlin Alexanderplatz, 736 m off: at home, so no country.
        expect(find.text('740 m · Mitte, Berlin'), findsWidgets);
        // Chur has no district; its canton stands in, and it is abroad.
        expect(find.textContaining('Grisons, CH'), findsOne);
      });

      testWidgets('results are drawn by what serves them', (tester) async {
        await _pump(tester);
        await search(tester);

        // S+U Alexanderplatz: rail, and more.
        expect(find.byIcon(LucideIcons.trainFront), findsOne);
        // Chur and Idar: buses. The two long-distance coach stops.
        expect(find.byIcon(LucideIcons.busFront), findsNWidgets(2));
        expect(find.byIcon(LucideIcons.bus), findsNWidgets(2));
        // A stop the geocoder named nothing for.
        expect(find.byIcon(kUnknownStopIcon), findsOne);
      });
    });
  });

  testWidgets(
    'recents are drawn by what serves them, favourites their own way',
    (tester) async {
      await _keep([
        // A railway station, kept as home: the rider chose that face.
        _favourite(id: 'a', name: 'Ostbahnhof', lon: 13.43, iconName: 'home'),
      ]);
      await _remember(SavedPlacesBucket.search, [
        _recent(
          'Hauptbahnhof',
          lon: 13.36,
          modes: const [TransitMode.longDistance],
        ),
        _recent('Am Kupfergraben', lon: 13.39, modes: const [TransitMode.tram]),
        _recent('Warschauer', lon: 13.44),
      ]);
      await _pump(tester);

      expect(find.byIcon(LucideIcons.house), findsOne);
      expect(find.byIcon(LucideIcons.trainFront), findsOne);
      expect(find.byIcon(LucideIcons.tramFront), findsOne);
      expect(find.byIcon(kUnknownStopIcon), findsOne);
    },
  );

  group('a stop search', () {
    testWidgets('lists a recent whose favourite it cannot open', (
      tester,
    ) async {
      // Kept before stop ids were recorded: Favourites leaves it out here,
      // so Recent must not.
      await _keep([
        _favourite(id: 'a', name: 'Ostkreuz', lon: 13.46, stopId: null),
      ]);
      await _remember(SavedPlacesBucket.timetable, [_recent('Ostkreuz')]);
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      expect(find.text('RECENT'), findsOne);
      expect(find.bySemanticsLabel('Keep Ostkreuz'), findsOne);
    });

    testWidgets('keeping that recent fills the id in, not a second one', (
      tester,
    ) async {
      await _keep([
        _favourite(id: 'a', name: 'Ostkreuz', lon: 13.46, stopId: null),
      ]);
      await _remember(SavedPlacesBucket.timetable, [_recent('Ostkreuz')]);
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      await tester.tap(find.bySemanticsLabel('Keep Ostkreuz'));
      await tester.pumpAndSettle();

      final kept = FavoritesService.favoritesListenable.value.single;
      expect(kept.id, 'a');
      expect(kept.stopId, 'de-DELFI_Ostkreuz');
      expect(find.text('RECENT'), findsNothing);
    });
  });

  group('reordering favourites', () {
    Future<void> keepThree() => _keep([
      _favourite(id: 'a', name: 'Alpha', lon: 13.1),
      _favourite(id: 'b', name: 'Bravo', lon: 13.2),
      _favourite(id: 'c', name: 'Charlie', lon: 13.3),
    ]);

    testWidgets('a favourite is dragged into a new order', (tester) async {
      await keepThree();
      await _pump(tester);

      // Rows are 56 high: past Bravo's middle, short of Charlie's.
      await _drag(tester, 'Alpha', 70);

      expect(_storedOrder(), ['b', 'a', 'c']);
      final bravo = tester.getRect(find.text('Bravo')).top;
      expect(tester.getRect(find.text('Alpha')).top, greaterThan(bravo));
    });

    testWidgets('dragged up as well as down', (tester) async {
      await keepThree();
      await _pump(tester);

      await _drag(tester, 'Charlie', -126);

      expect(_storedOrder(), ['c', 'a', 'b']);
    });

    testWidgets('in a stop search, what it hides keeps its place', (
      tester,
    ) async {
      await _keep([
        _favourite(id: 'a', name: 'Alpha', lon: 13.1),
        _favourite(id: 'x', name: 'An address', type: 'ADDRESS', lon: 13.5),
        _favourite(id: 'b', name: 'Bravo', lon: 13.2),
      ]);
      await _pump(tester, type: 'STOP', bucket: SavedPlacesBucket.timetable);

      await _drag(tester, 'Alpha', 70);

      expect(_storedOrder(), ['b', 'x', 'a']);
    });

    testWidgets('held still, a favourite opens its menu and stays put', (
      tester,
    ) async {
      await keepThree();
      await _pump(tester);

      final gesture = await _press(
        tester,
        'Alpha',
        past: const Duration(milliseconds: 600),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Edit Favourite'), findsOne);

      // What the finger does after the menu opens is not a drag.
      await gesture.moveBy(const Offset(0, 120));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_storedOrder(), ['a', 'b', 'c']);
    });

    testWidgets('let go after the lift, it is only a lift', (tester) async {
      await keepThree();
      await _pump(tester);

      final gesture = await _press(tester, 'Alpha');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Edit Favourite'), findsNothing);
      expect(_storedOrder(), ['a', 'b', 'c']);
    });

    testWidgets('moving after the lift is a drag, never the menu', (
      tester,
    ) async {
      await keepThree();
      await _pump(tester);

      final gesture = await _press(tester, 'Alpha');
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Edit Favourite'), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a screen reader moves one without dragging', (tester) async {
      final semantics = tester.ensureSemantics();
      await keepThree();
      await _pump(tester);

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('^Alpha')),
        const CustomSemanticsAction(label: 'Move down'),
      );
      await tester.pumpAndSettle();
      expect(_storedOrder(), ['b', 'a', 'c']);

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('^Charlie')),
        const CustomSemanticsAction(label: 'Move up'),
      );
      await tester.pumpAndSettle();
      expect(_storedOrder(), ['b', 'c', 'a']);

      // Nowhere past the ends to go.
      expect(
        tester.getSemantics(find.text('Bravo')),
        isNot(
          containsSemantics(
            customActions: [const CustomSemanticsAction(label: 'Move up')],
          ),
        ),
      );
      semantics.dispose();
    });
  });
}
