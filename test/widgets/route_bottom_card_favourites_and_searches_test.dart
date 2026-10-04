import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/recent_search.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

import '../support/bottom_card_host.dart';
import '../support/plan_fixtures.dart';

/// Literal, as a build that wrote it will have.
const String _homeSections = 'home_sections';

SavedTrip _trip() => SavedTrip.fromItinerary(
  itinerary: Itinerary.fromJson(
    planItineraryJson(departure: DateTime.utc(2026, 9, 28, 8), tripId: 't'),
  ),
  fromName: 'Opened from',
  toName: 'Opened to',
);

RecentSearch _search(String from, String to) => RecentSearch(
  from: RecentSearchEnd.of(
    TransitousLocationSuggestion(
      id: from,
      name: from,
      lat: 1,
      lon: 1,
      type: 'PLACE',
    ),
  ),
  to: RecentSearchEnd.of(
    TransitousLocationSuggestion(
      id: to,
      name: to,
      lat: 2,
      lon: 2,
      type: 'PLACE',
    ),
  ),
  searchedAt: DateTime.utc(2026, 9, 28, 8),
);

FavoritePlace _favourite(String name, {String? label}) => FavoritePlace(
  id: 'fav-$name',
  name: name,
  label: label,
  lat: 52.5,
  lon: 13.4,
  addedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  List<String>? sections,
  List<RecentSearch> searches = const [],
  List<FavoritePlace> favourites = const [],
  ValueChanged<RecentSearch>? onSearchTap,
  ValueChanged<FavoritePlace>? onFavouriteTap,
  bool offerFavourites = true,
}) async {
  SharedPreferencesAsyncPlatform.instance = sections == null
      ? InMemorySharedPreferencesAsync.empty()
      : InMemorySharedPreferencesAsync.withData({_homeSections: sections});
  FavoritesService.favoritesListenable.value = List.unmodifiable(favourites);

  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    BottomCardHost(
      recentTrips: [_trip()],
      recentSearches: searches,
      onRecentSearchTap: onSearchTap,
      onFavoriteTap: offerFavourites ? (onFavouriteTap ?? (_) {}) : null,
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('by default', () {
    testWidgets('the card is as it was: recent trips, and no new lists', (
      tester,
    ) async {
      await _pump(
        tester,
        searches: [_search('A', 'B')],
        favourites: [_favourite('Home')],
      );

      expect(find.text('Recent trips'), findsOneWidget);
      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Favourites'), findsNothing);
      expect(find.text('A'), findsNothing);
      expect(find.text('Home'), findsNothing);
    });
  });

  group('recent searches', () {
    testWidgets('are listed once switched on, apart from recent trips', (
      tester,
    ) async {
      await _pump(
        tester,
        sections: ['recentTrips:1', 'recentSearches:1'],
        searches: [_search('Home', 'Work'), _search('Gym', 'Cafe')],
      );

      expect(find.text('Recent trips'), findsOneWidget);
      expect(find.text('Recent searches'), findsOneWidget);
      for (final name in ['Home', 'Work', 'Gym', 'Cafe']) {
        expect(find.text(name), findsOneWidget);
      }
      // The opened connection is still its own list.
      expect(find.text('Opened from'), findsOneWidget);
    });

    testWidgets('can stand in for recent trips', (tester) async {
      await _pump(
        tester,
        sections: ['recentTrips:0', 'recentSearches:1'],
        searches: [_search('Home', 'Work')],
      );

      expect(find.text('Recent trips'), findsNothing);
      expect(find.text('Opened from'), findsNothing);
      expect(find.text('Recent searches'), findsOneWidget);
    });

    testWidgets('show no heading while there are none', (tester) async {
      await _pump(tester, sections: ['recentSearches:1']);

      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('hand back the search that was tapped', (tester) async {
      RecentSearch? tapped;
      final second = _search('Gym', 'Cafe');
      await _pump(
        tester,
        sections: ['recentSearches:1'],
        searches: [_search('Home', 'Work'), second],
        onSearchTap: (s) => tapped = s,
      );

      await tester.tap(find.text('Cafe'));

      expect(tapped, same(second));
    });

    testWidgets('say what tapping does', (tester) async {
      await _pump(
        tester,
        sections: ['recentSearches:1'],
        searches: [_search('Home', 'Work')],
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Search again from Home to Work',
        ),
        findsOneWidget,
      );
    });
  });

  group('favourites', () {
    testWidgets('are a row of shortcuts once switched on', (tester) async {
      await _pump(
        tester,
        sections: ['favorites:1', 'recentTrips:1'],
        favourites: [_favourite('Home'), _favourite('Work')],
      );

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('go by the rider\'s name for a place, not the searched one', (
      tester,
    ) async {
      await _pump(
        tester,
        sections: ['favorites:1'],
        favourites: [_favourite('Hauptbahnhof', label: 'Station')],
      );

      expect(find.text('Station'), findsOneWidget);
      expect(find.text('Hauptbahnhof'), findsNothing);
    });

    testWidgets('hand back the favourite that was tapped', (tester) async {
      FavoritePlace? tapped;
      final work = _favourite('Work');
      await _pump(
        tester,
        sections: ['favorites:1'],
        favourites: [_favourite('Home'), work],
        onFavouriteTap: (f) => tapped = f,
      );

      await tester.tap(find.text('Work'));

      expect(tapped, same(work));
    });

    testWidgets('say how to get some when there are none', (tester) async {
      await _pump(tester, sections: ['favorites:1']);

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('No favourites yet'), findsOneWidget);
    });

    testWidgets('are not offered when the screen cannot go to one', (
      tester,
    ) async {
      await _pump(
        tester,
        sections: ['favorites:1'],
        favourites: [_favourite('Home')],
        offerFavourites: false,
      );

      expect(find.text('Favourites'), findsNothing);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('follow places kept while the card is open', (tester) async {
      await _pump(tester, sections: ['favorites:1']);
      expect(find.text('No favourites yet'), findsOneWidget);

      FavoritesService.favoritesListenable.value = [_favourite('Home')];
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('No favourites yet'), findsNothing);
    });
  });

  testWidgets('all four follow the order that was chosen', (tester) async {
    await _pump(
      tester,
      sections: [
        'recentSearches:1',
        'favorites:1',
        'departures:0',
        'recentTrips:1',
      ],
      searches: [_search('Home', 'Work')],
      favourites: [_favourite('Shortcut')],
    );

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Recent searches'), lessThan(top('Favourites')));
    expect(top('Favourites'), lessThan(top('Recent trips')));
  });
}
