import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/constants/prefs_keys.dart';
import 'package:transportia/migrations/storage_migrations.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/utils/app_version.dart';

/// Storage as 1.0.3 left it. Written as literals rather than through
/// [PrefsKeys], because these are the names a released build used — the
/// constants have since moved on, and a test that followed them would pass
/// even if the migration did nothing.
const String _oldWelcomeSeen = 'welcome_seen_v1';
const String _oldSavedPlacesSearch = 'saved_places_search_v1';
const String _oldSavedPlacesTimetable = 'saved_places_timetable_v1';
const String _ignoredUpdateVersion = 'ignored_update_version';
const String _recentTrips = 'recent_trips';

/// One recent search as 1.0.3 wrote it: two places and a timestamp.
const String _recentPairsIn103 =
    '[{"fromName":"My Location","fromLat":52.5,"fromLon":13.4,'
    '"toName":"Alexanderplatz","toLat":52.52,"toLon":13.41,'
    '"timestamp":1767225600000}]';

/// Every mode the 1.0.3 Transit options screen offered, which is what it wrote
/// when the user had deselected nothing.
const List<String> _allModesIn103 = [
  'WALK',
  'BIKE',
  'RENTAL',
  'CAR',
  'CAR_PARKING',
  'CAR_DROPOFF',
  'ODM',
  'FLEX',
  'TRANSIT',
  'TRAM',
  'SUBWAY',
  'FERRY',
  'AIRPLANE',
  'SUBURBAN',
  'BUS',
  'COACH',
  'RAIL',
  'HIGHSPEED_RAIL',
  'LONG_DISTANCE',
  'NIGHT_RAIL',
  'REGIONAL_FAST_RAIL',
  'REGIONAL_RAIL',
  'CABLE_CAR',
  'FUNICULAR',
  'AERIAL_LIFT',
  'AREAL_LIFT',
  'OTHER',
  'METRO',
];

void _seed(Map<String, Object> data) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
}

/// A 1.0.3 install someone actually used.
Map<String, Object> _usedIn103() => {
  _oldWelcomeSeen: true,
  _oldSavedPlacesSearch: '[{"name":"Alexanderplatz"}]',
  _oldSavedPlacesTimetable: '[{"name":"Hauptbahnhof"}]',
  PrefsKeys.favoritePlaces: '[]',
  PrefsKeys.transitWalkingSpeed: 5.2,
  PrefsKeys.transitTransferBuffer: 8,
  PrefsKeys.transitSelectedModes: const ['BUS', 'RAIL'],
  _ignoredUpdateVersion: '1.0.2',
};

Future<RoutingOptions?> _storedOptions(SharedPreferencesAsync prefs) async {
  final raw = await prefs.getString(PrefsKeys.routingOptions);
  if (raw == null) return null;
  return RoutingOptions.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppVersion.setForTesting('1.0.4'));
  tearDown(() => AppVersion.setForTesting(null));

  group('upgrading a 1.0.3 install', () {
    test('renamed keys carry their values across, old names gone', () async {
      _seed(_usedIn103());
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(
        await prefs.getString(PrefsKeys.savedPlacesSearch),
        '[{"name":"Alexanderplatz"}]',
      );
      expect(
        await prefs.getString(PrefsKeys.savedPlacesTimetable),
        '[{"name":"Hauptbahnhof"}]',
      );
      expect(await prefs.containsKey(_oldSavedPlacesSearch), isFalse);
      expect(await prefs.containsKey(_oldSavedPlacesTimetable), isFalse);
    });

    test('onboarding is not shown again', () async {
      // Its own case: losing this flag re-runs the welcome flow for every
      // existing user, which is the most visible way this can go wrong.
      _seed(_usedIn103());
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getBool(PrefsKeys.welcomeSeen), isTrue);
      expect(await prefs.containsKey(_oldWelcomeSeen), isFalse);
    });

    test(
      'the three routing scalars become one blob, and are removed',
      () async {
        _seed(_usedIn103());
        final prefs = SharedPreferencesAsync();

        await StorageMigrations.run();

        final options = await _storedOptions(prefs);
        expect(options, isNotNull);
        expect(options!.walkingSpeedKmh, 5.2);
        expect(options.additionalTransferTime, const Duration(minutes: 8));
        expect(options.transitModes, [TransitMode.bus, TransitMode.rail]);

        expect(await prefs.containsKey(PrefsKeys.transitWalkingSpeed), isFalse);
        expect(
          await prefs.containsKey(PrefsKeys.transitTransferBuffer),
          isFalse,
        );
        expect(
          await prefs.containsKey(PrefsKeys.transitSelectedModes),
          isFalse,
        );
      },
    );

    test('a full mode selection becomes no restriction', () async {
      _seed({
        _oldWelcomeSeen: true,
        PrefsKeys.transitSelectedModes: _allModesIn103,
      });
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect((await _storedOptions(prefs))!.transitModes, isEmpty);
    });

    test('no routing scalars leaves no blob behind', () async {
      // Writing defaults here would turn "never configured" into "configured
      // to the defaults", which is a different thing on the options screen.
      _seed({_oldWelcomeSeen: true, PrefsKeys.favoritePlaces: '[]'});
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.containsKey(PrefsKeys.routingOptions), isFalse);
    });

    test('the dropped update-prompt key is removed', () async {
      _seed(_usedIn103());
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.containsKey(_ignoredUpdateVersion), isFalse);
    });

    test(
      'recent searches, which have no connection to keep, are dropped',
      () async {
        _seed({..._usedIn103(), _recentTrips: _recentPairsIn103});
        final prefs = SharedPreferencesAsync();

        await StorageMigrations.run();

        expect(await prefs.containsKey(_recentTrips), isFalse);
      },
    );

    test('a recent list that already holds connections is kept', () async {
      const snapshots = '[{"id":"a","itinerary":{}}]';
      _seed({..._usedIn103(), _recentTrips: snapshots});
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getString(_recentTrips), snapshots);
    });

    test('storage is stamped with the running version', () async {
      _seed(_usedIn103());
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.4');
    });

    test('running twice is the same as running once', () async {
      _seed(_usedIn103());
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();
      final afterFirst = await _storedOptions(prefs);
      await StorageMigrations.run();

      expect(await _storedOptions(prefs), afterFirst);
      expect(await prefs.getBool(PrefsKeys.welcomeSeen), isTrue);
      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.4');
    });
  });

  group('storage that needs no migration', () {
    test('a fresh install is stamped and otherwise untouched', () async {
      _seed({});
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.4');
      expect(await prefs.containsKey(PrefsKeys.welcomeSeen), isFalse);
      expect(await prefs.containsKey(PrefsKeys.routingOptions), isFalse);
    });

    test('an install already on 1.0.4 is left alone', () async {
      _seed({
        PrefsKeys.storageVersion: '1.0.4',
        PrefsKeys.routingOptions: '{"walkingSpeedKmh":6.1}',
      });
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect((await _storedOptions(prefs))!.walkingSpeedKmh, 6.1);
    });

    test('storage from a newer build is not rewritten or restamped', () async {
      _seed({
        PrefsKeys.storageVersion: '1.0.5',
        PrefsKeys.routingOptions: '{"walkingSpeedKmh":6.1}',
      });
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.5');
      expect((await _storedOptions(prefs))!.walkingSpeedKmh, 6.1);
    });

    test('1.0.10 counts as newer than 1.0.4, not older', () async {
      // String comparison would read '1.0.10' as below '1.0.4' and downgrade
      // storage that a later build wrote.
      _seed({PrefsKeys.storageVersion: '1.0.10'});
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.10');
    });
  });

  group('when things go wrong', () {
    test('an unreadable routing blob does not stop the rest', () async {
      _seed({..._usedIn103(), PrefsKeys.routingOptions: 'not json'});
      final prefs = SharedPreferencesAsync();

      await StorageMigrations.run();

      // The blob is already present, so the scalars are dropped untouched and
      // the renames still happen.
      expect(await prefs.getBool(PrefsKeys.welcomeSeen), isTrue);
      expect(await prefs.getString(PrefsKeys.storageVersion), '1.0.4');
    });
  });
}
