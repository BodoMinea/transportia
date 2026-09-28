import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/widgets/error_notice.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/saved_place.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/timetables_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/screens/location_search_screen.dart';
import 'package:transportia/services/saved_places_service.dart';

FavoritePlace _favourite({
  required String id,
  required String name,
  String type = 'STOP',
  String? label,
  double lat = 52.5,
  double lon = 13.4,
  // Defaults to a real feed id, because that is what makes a station
  // offerable here. Pass null for one kept before ids were stored.
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

SavedPlace _stop({
  required String name,
  String type = 'STOP',
  double lat = 52.52,
  double lon = 13.41,
  String? stopId = 'de-DELFI_de:11000:900120005',
}) => SavedPlace(
  name: name,
  type: type,
  lat: lat,
  lon: lon,
  stopId: type.toUpperCase() == 'STOP' ? stopId : null,
  importance: SavedPlacesService.initialImportance,
);

TransitousClient _clientReturning(
  Future<http.Response> Function(http.Request request) handler,
) => TransitousClient(httpClient: MockClient(handler));

/// A stop the server knows but which has nothing leaving right now — enough to
/// prove the departures view was reached.
Future<http.Response> _emptyDepartures(http.Request request) async =>
    http.Response(
      jsonEncode({'stopTimes': <Object>[]}),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<http.Response> _serverError(http.Request request) async =>
    http.Response('upstream is down', 502);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1000);
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
        supportedLocales: const [Locale('en', 'US')],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => const TimetablesScreen(),
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
    TransitousClient.instance = _clientReturning(_emptyDepartures);
  });

  tearDown(() => TransitousClient.instance = TransitousClient());

  testWidgets('with nothing remembered it still says what to do', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Tap the heart on a place to keep it here.'), findsOne);
  });

  testWidgets('recent stops are offered before anything is searched for', (
    tester,
  ) async {
    // Choosing a stop is what this screen is for, and the stops already
    // picked here are the likeliest answers.
    await SavedPlacesService.savePlaces(
      bucket: SavedPlacesBucket.timetable,
      places: [
        _stop(name: 'Alexanderplatz'),
        _stop(name: 'Hauptbahnhof'),
      ],
    );

    await _pump(tester);

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Alexanderplatz'), findsOneWidget);
    expect(find.text('Hauptbahnhof'), findsOneWidget);
  });

  testWidgets('a remembered place that is not a stop is left out', (
    tester,
  ) async {
    // The screen can only open departures for a stop, so anything else would
    // be a dead end.
    await SavedPlacesService.savePlaces(
      bucket: SavedPlacesBucket.timetable,
      places: [_stop(name: 'Somewhere', type: 'ADDRESS')],
    );

    await _pump(tester);

    expect(find.text('Somewhere'), findsNothing);
  });

  testWidgets('favourite stations appear, and only the stations', (
    tester,
  ) async {
    await FavoritesService.saveFavorite(
      _favourite(id: 'a', name: 'Ostkreuz', label: 'Home'),
    );
    await FavoritesService.saveFavorite(
      _favourite(id: 'b', name: 'A street', type: 'ADDRESS', lat: 52.1),
    );

    await _pump(tester);

    expect(find.text('FAVOURITES'), findsOneWidget);
    // The alias leads, the searched name sits under it.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ostkreuz'), findsOneWidget);
    expect(find.text('A street'), findsNothing);
  });

  testWidgets('no favourite station means no favourites section', (
    tester,
  ) async {
    await FavoritesService.saveFavorite(
      _favourite(id: 'b', name: 'A street', type: 'ADDRESS'),
    );

    await _pump(tester);

    // The heading stays — it is where you are told how to fill the list —
    // but the address is not offered, because it cannot answer a departure
    // board.
    expect(find.text('A street'), findsNothing);
    expect(find.text('None of your favourites is a stop.'), findsOne);
  });

  testWidgets('the screen is the stop search, not a door to one', (
    tester,
  ) async {
    // It used to keep a read-only field that pushed a picker showing the same
    // two lists. One search field, on this screen, and no route to push.
    await _pump(tester);

    expect(find.byType(LocationSearchBody), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
  });

  testWidgets('a point on the map is not offered for a stop', (tester) async {
    // A coordinate cannot answer a departure board.
    await _pump(tester);
    expect(find.bySemanticsLabel('Pick a point on the map'), findsNothing);
  });

  group('opening a favourite', () {
    testWidgets('tapping one opens its departures, with no second search', (
      tester,
    ) async {
      // The whole point of the screen: picking a stop is the question, so the
      // answer should not be another field to fill in.
      await FavoritesService.saveFavorite(
        _favourite(id: 'a', name: 'Ostkreuz'),
      );

      await _pump(tester);
      await tester.tap(find.text('Ostkreuz'));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSearchBody), findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('the stop the server is asked about is the feed id', (
      tester,
    ) async {
      // A favourite's own id is local ('fav_<micros>'); sending it would 400.
      String? askedFor;
      TransitousClient.instance = _clientReturning((request) {
        askedFor = request.url.queryParameters['stopId'];
        return _emptyDepartures(request);
      });
      await FavoritesService.saveFavorite(
        _favourite(id: 'a', name: 'Ostkreuz', stopId: 'de-DELFI_stop:42'),
      );

      await _pump(tester);
      await tester.tap(find.text('Ostkreuz'));
      await tester.pumpAndSettle();

      expect(askedFor, 'de-DELFI_stop:42');
    });

    testWidgets('a station with no stored id is not offered', (tester) async {
      // Kept before the id was recorded. Tapping it could only fail, so it is
      // left out rather than offered as a dead end.
      await FavoritesService.saveFavorite(
        _favourite(id: 'a', name: 'Ostkreuz', stopId: null),
      );

      await _pump(tester);

      expect(find.text('Ostkreuz'), findsNothing);
      expect(find.text('None of your favourites is a stop.'), findsOne);
    });

    testWidgets('a recent stop with no stored id is not offered', (
      tester,
    ) async {
      await SavedPlacesService.savePlaces(
        bucket: SavedPlacesBucket.timetable,
        places: [_stop(name: 'Alexanderplatz', stopId: null)],
      );

      await _pump(tester);

      expect(find.text('Alexanderplatz'), findsNothing);
    });

    testWidgets('a failed load says so instead of asking again', (
      tester,
    ) async {
      // The reported bug: the failure left the body with nothing to show, so
      // it fell back to the picker and a second search bar appeared under the
      // stop that had just been chosen.
      TransitousClient.instance = _clientReturning(_serverError);
      await FavoritesService.saveFavorite(
        _favourite(id: 'a', name: 'Ostkreuz'),
      );

      await _pump(tester);
      await tester.tap(find.text('Ostkreuz'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorNotice), findsOneWidget);
      expect(find.byType(LocationSearchBody), findsNothing);
      // The stop stays chosen, so retrying does not mean picking it again.
      expect(find.byType(EditableText), findsOneWidget);
    });
  });

  group('remembering a stop', () {
    const alexId = 'de-DELFI_de:11000:900100003';

    /// Answers the geocoder and the departure board with the real captures.
    Future<http.Response> captured(http.Request request) async {
      final path = request.url.path;
      final name = path.contains('geocode')
          ? 'geocode.json'
          : path.contains('stoptimes')
          ? 'stoptimes.json'
          : null;
      if (name == null) return http.Response('not captured', 404);
      return http.Response(
        File('test/fixtures/transitous/$name').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    Future<List<SavedPlace>> remembered() =>
        SavedPlacesService.loadPlaces(bucket: SavedPlacesBucket.timetable);

    testWidgets('a pick is remembered once, with its id and what serves it', (
      tester,
    ) async {
      // It used to be written twice — by the search without the id, and by
      // this screen — and whichever landed last won.
      TransitousClient.instance = _clientReturning(captured);
      await _pump(tester);

      await tester.enterText(find.byType(EditableText), 'Alexanderplatz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('S+U Alexanderplatz Bhf (Berlin)'));
      await tester.pumpAndSettle();

      final stored = await remembered();
      expect(stored, hasLength(1));
      expect(stored.single.stopId, alexId);
      expect(stored.single.modes, contains(TransitMode.subway));
    });

    testWidgets('opening a board fills in what serves a remembered stop', (
      tester,
    ) async {
      // Remembered before modes were, and picked from the recents, so the
      // geocoder is never asked again: the board is the one that can say.
      TransitousClient.instance = _clientReturning(captured);
      await SavedPlacesService.savePlaces(
        bucket: SavedPlacesBucket.timetable,
        places: [_stop(name: 'Alexanderplatz', stopId: alexId)],
      );
      expect((await remembered()).single.modes, isEmpty);

      await _pump(tester);
      await tester.tap(find.text('Alexanderplatz'));
      await tester.pumpAndSettle();

      expect((await remembered()).single.modes, contains(TransitMode.subway));
    });
  });
}
