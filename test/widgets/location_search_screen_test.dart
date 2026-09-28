import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/my_location.dart';
import 'package:transportia/screens/favourites_map_screen.dart';
import 'package:transportia/screens/location_search_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/models/saved_place.dart';
import 'package:transportia/services/saved_places_service.dart';

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
}) => FavoritePlace(
  id: id,
  name: name,
  label: label,
  type: type,
  stopId: type.toUpperCase() == 'STOP' ? stopId : null,
  lat: lat,
  lon: lon,
  addedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _keep(List<FavoritePlace> favourites) async {
  for (final favourite in favourites) {
    await FavoritesService.saveFavorite(favourite);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  bool showMyLocation = false,
  String? type,
  SavedPlacesBucket bucket = SavedPlacesBucket.search,
  String confirmLabel = 'Use as destination',
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
            confirmLabel: confirmLabel,
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
    expect(picker.title, 'Destination');
    expect(picker.confirmLabel, 'Use as destination');
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

  testWidgets('a favourite offers its actions from the row and a long press', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    expect(find.bySemanticsLabel('Edit Hauptbahnhof'), findsOne);

    await tester.longPress(find.text('Hauptbahnhof'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Favourite'), findsOne);
    expect(find.text('Remove favourite'), findsOne);
  });

  testWidgets('renaming writes the alias and leaves the name alone', (
    tester,
  ) async {
    await _keep([_favourite(id: 'a', name: 'Hauptbahnhof')]);
    await _pump(tester);

    await tester.longPress(find.text('Hauptbahnhof'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = FavoritesService.favoritesListenable.value.single;
    expect(stored.label, 'Home');
    expect(stored.name, 'Hauptbahnhof');
    expect(stored.displayName, 'Home');
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
}
