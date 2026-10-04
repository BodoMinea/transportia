import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/my_location.dart';
import 'package:transportia/models/recent_search.dart';
import 'package:transportia/services/recent_searches_service.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

final DateTime _monday = DateTime.utc(2026, 9, 28, 8);

TransitousLocationSuggestion _place(
  String name, {
  double lat = 52.5,
  double lon = 13.4,
  String type = 'PLACE',
  String? stopId,
}) => TransitousLocationSuggestion(
  id: 'any-$name',
  name: name,
  lat: lat,
  lon: lon,
  type: type,
  stopId: stopId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('nothing searched yet is an empty list', () async {
    expect(await RecentSearchesService.getRecentSearches(), isEmpty);
  });

  test('the search run last comes first', () async {
    await RecentSearchesService.record(
      from: _place('Home', lat: 1),
      to: _place('Work', lat: 2),
    );
    await RecentSearchesService.record(
      from: _place('Home', lat: 1),
      to: _place('Gym', lat: 3),
    );

    final searches = await RecentSearchesService.getRecentSearches();

    expect(searches.map((s) => s.to.name), ['Gym', 'Work']);
  });

  test(
    'the same search again moves up rather than being listed twice',
    () async {
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Work', lat: 2),
      );
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Gym', lat: 3),
      );
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Work', lat: 2),
      );

      final searches = await RecentSearchesService.getRecentSearches();

      expect(searches.map((s) => s.to.name), ['Work', 'Gym']);
    },
  );

  test('a place picked slightly differently is the same search', () async {
    await RecentSearchesService.record(
      from: _place('Home', lat: 52.5201, lon: 13.4001),
      to: _place('Work', lat: 52.3, lon: 13.5),
    );
    await RecentSearchesService.record(
      from: _place('Home', lat: 52.52014, lon: 13.40012),
      to: _place('Work', lat: 52.3, lon: 13.5),
    );

    expect(await RecentSearchesService.getRecentSearches(), hasLength(1));
  });

  test('the same two places the other way round are another search', () async {
    await RecentSearchesService.record(
      from: _place('Home', lat: 1),
      to: _place('Work', lat: 2),
    );
    await RecentSearchesService.record(
      from: _place('Work', lat: 2),
      to: _place('Home', lat: 1),
    );

    expect(await RecentSearchesService.getRecentSearches(), hasLength(2));
  });

  test('only the last few are kept', () async {
    for (var i = 0; i < RecentSearchesService.maxSearches + 3; i++) {
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Place $i', lat: 10.0 + i),
      );
    }

    final searches = await RecentSearchesService.getRecentSearches();

    expect(searches, hasLength(RecentSearchesService.maxSearches));
    expect(searches.first.to.name, 'Place 7');
    expect(searches.map((s) => s.to.name), isNot(contains('Place 0')));
  });

  group('My Location', () {
    test(
      'is kept as where the rider is, with no position of its own',
      () async {
        await RecentSearchesService.record(
          from: myLocationSuggestion,
          to: _place('Work', lat: 2),
          now: _monday,
        );

        final search = (await RecentSearchesService.getRecentSearches()).single;

        expect(search.from.isMyLocation, isTrue);
        expect(search.from.name, myLocationName);
        expect(search.to.isMyLocation, isFalse);
      },
    );

    test('comes back as the My Location selection', () async {
      await RecentSearchesService.record(
        from: myLocationSuggestion,
        to: _place('Work', lat: 2),
      );

      final search = (await RecentSearchesService.getRecentSearches()).single;

      expect(search.from.toSuggestion().isMyLocation, isTrue);
      expect(search.to.toSuggestion().isMyLocation, isFalse);
    });

    test(
      'from here to Work and from Home to Work are different searches',
      () async {
        await RecentSearchesService.record(
          from: myLocationSuggestion,
          to: _place('Work', lat: 2),
        );
        await RecentSearchesService.record(
          from: _place('Home', lat: 1),
          to: _place('Work', lat: 2),
        );

        expect(await RecentSearchesService.getRecentSearches(), hasLength(2));
      },
    );
  });

  test('a station comes back as a station, with its id', () async {
    await RecentSearchesService.record(
      from: _place('Home', lat: 1),
      to: _place(
        'Hauptbahnhof',
        lat: 2,
        type: 'STOP',
        stopId: 'de-VBB_de:11000:900003201',
      ),
    );

    final to = (await RecentSearchesService.getRecentSearches()).single.to
        .toSuggestion();

    expect(to.type, 'STOP');
    expect(to.stopId, 'de-VBB_de:11000:900003201');
    expect(to.name, 'Hauptbahnhof');
    expect(to.lat, 2);
  });

  test('the time of the search is kept', () async {
    await RecentSearchesService.record(
      from: _place('Home', lat: 1),
      to: _place('Work', lat: 2),
      now: _monday,
    );

    final search = (await RecentSearchesService.getRecentSearches()).single;

    expect(search.searchedAt, _monday);
  });

  group('storage', () {
    test('is its own key, apart from the recent trips', () async {
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Work', lat: 2),
      );

      final prefs = SharedPreferencesAsync();
      expect(await prefs.containsKey('recent_searches'), isTrue);
      expect(await prefs.containsKey('recent_trips'), isFalse);
    });

    test('leaves the recent trips alone', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'recent_trips': '[]'});

      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Work', lat: 2),
      );

      expect(await SharedPreferencesAsync().getString('recent_trips'), '[]');
    });

    test('an entry that cannot be read is dropped, not the list', () async {
      final good = RecentSearch(
        from: RecentSearchEnd.of(_place('Home', lat: 1)),
        to: RecentSearchEnd.of(_place('Work', lat: 2)),
        searchedAt: _monday,
      );
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'recent_searches': jsonEncode([
              {'from': 'nonsense'},
              good.toJson(),
            ]),
          });

      final searches = await RecentSearchesService.getRecentSearches();

      expect(searches, hasLength(1));
      expect(searches.single.to.name, 'Work');
    });

    test('nonsense in storage is an empty list', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'recent_searches': 'not json',
          });

      expect(await RecentSearchesService.getRecentSearches(), isEmpty);
    });

    test('clearing forgets them all', () async {
      await RecentSearchesService.record(
        from: _place('Home', lat: 1),
        to: _place('Work', lat: 2),
      );

      await RecentSearchesService.clearHistory();

      expect(await RecentSearchesService.getRecentSearches(), isEmpty);
    });
  });
}
