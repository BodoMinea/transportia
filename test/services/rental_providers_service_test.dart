import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/models/rental_provider_prefs.dart';
import 'package:transportia/providers/backend_provider.dart';
import 'package:transportia/services/rental_providers_service.dart';

final _groups = File(
  'test/fixtures/transitous/rentals_groups.json',
).readAsStringSync();

final _now = DateTime.utc(2026, 9, 29, 12);

/// Answers every request with [body] (or fails with [status]) and records
/// what was asked.
List<Uri> _serve({String? body, int status = 200}) {
  final requests = <Uri>[];
  TransitousClient.instance = TransitousClient(
    httpClient: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        body ?? _groups,
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  return requests;
}

/// A cached list as an earlier session would have written it.
Future<void> _seedCache({
  required String host,
  required DateTime fetchedAt,
  List<Map<String, dynamic>> groups = const [
    {'id': 'Cached', 'name': 'Cached', 'providers': [], 'formFactors': []},
  ],
}) => SharedPreferencesAsync().setString(
  'rental_catalogue',
  json.encode({
    'host': host,
    'fetchedAt': fetchedAt.toIso8601String(),
    'groups': groups,
  }),
);

List<String>? _catalogueIds() => [
  for (final group in RentalProvidersService.catalogueListenable.value ?? [])
    group.id,
];

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    RentalProvidersService.invalidate();
  });
  tearDown(() => TransitousClient.instance = TransitousClient());

  group('provider list', () {
    test('fetches only the groups, and drops the one without an id', () async {
      final requests = _serve();

      await RentalProvidersService.ensureCatalogue(now: _now);

      final query = requests.single.queryParameters;
      expect(requests.single.path, '/api/v1/rentals');
      expect(query['withProviders'], 'false');
      expect(query.containsKey('min'), isFalse);
      final groups = RentalProvidersService.catalogueListenable.value!;
      expect(groups, isNotEmpty);
      expect(groups.every((g) => g.id.isNotEmpty), isTrue);
      expect(
        groups.length,
        (json.decode(_groups)['providerGroups'] as List).length - 1,
      );
    });

    test('a fresh cached list is used without asking', () async {
      final requests = _serve();
      await _seedCache(
        host: BackendProvider.defaultHost,
        fetchedAt: _now.subtract(const Duration(days: 1)),
      );

      await RentalProvidersService.ensureCatalogue(now: _now);

      expect(requests, isEmpty);
      expect(_catalogueIds(), ['Cached']);
    });

    test('a stale cached list is replaced', () async {
      final requests = _serve();
      await _seedCache(
        host: BackendProvider.defaultHost,
        fetchedAt: _now.subtract(
          RentalProvidersService.catalogueMaxAge + const Duration(hours: 1),
        ),
      );

      await RentalProvidersService.ensureCatalogue(now: _now);

      expect(requests, hasLength(1));
      expect(_catalogueIds(), isNot(contains('Cached')));
    });

    test("another host's list is not shown", () async {
      final requests = _serve(body: '{}', status: 500);
      await _seedCache(host: 'motis.example.org', fetchedAt: _now);

      await RentalProvidersService.ensureCatalogue(now: _now);

      expect(requests, hasLength(1));
      expect(RentalProvidersService.catalogueListenable.value, isNull);
    });

    test('a failed fetch keeps the stale list', () async {
      _serve(body: '{}', status: 503);
      await _seedCache(
        host: BackendProvider.defaultHost,
        fetchedAt: _now.subtract(const Duration(days: 30)),
      );

      await RentalProvidersService.ensureCatalogue(now: _now);

      expect(_catalogueIds(), ['Cached']);
    });

    test('a fetched list is there on the next start', () async {
      _serve();
      await RentalProvidersService.ensureCatalogue(now: _now);
      final fetched = _catalogueIds();

      RentalProvidersService.invalidate();
      final requests = _serve();
      await RentalProvidersService.ensureCatalogue(
        now: _now.add(const Duration(hours: 1)),
      );

      expect(requests, isEmpty);
      expect(_catalogueIds(), fetched);
    });
  });

  group('nearby', () {
    test('asks for groups only, and remembers the answer', () async {
      final requests = _serve();
      const berlin = LatLng(52.521, 13.401);

      final first = await RentalProvidersService.nearbyGroupIds(berlin);
      await RentalProvidersService.nearbyGroupIds(
        const LatLng(52.5212, 13.4013),
      );

      expect(first, isNotEmpty);
      expect(requests, hasLength(1));
      final query = requests.single.queryParameters;
      expect(query['point'], isNotNull);
      for (final flag in [
        'withProviders',
        'withStations',
        'withVehicles',
        'withZones',
      ]) {
        expect(query[flag], 'false', reason: flag);
      }
    });

    test('says nothing when the server cannot answer', () async {
      _serve(body: '{}', status: 500);

      expect(
        await RentalProvidersService.nearbyGroupIds(const LatLng(0, 0)),
        isEmpty,
      );
    });
  });

  group('picks', () {
    const voi = PickedProviderGroup(id: 'Voi Technology AB', name: 'Voi');

    test('survive a restart', () async {
      await RentalProvidersService.add(voi);
      RentalProvidersService.invalidate();

      final prefs = await RentalProvidersService.loadPrefs();
      expect(prefs.groups.single.id, voi.id);
      expect(prefs.limit, isTrue);
    });

    test('are sent only while the limit is on', () async {
      await RentalProvidersService.add(voi);
      expect(await RentalProvidersService.activeGroupIds(), [voi.id]);

      await RentalProvidersService.setLimit(false);
      expect(await RentalProvidersService.activeGroupIds(), isEmpty);
    });

    test('an unreadable stored value means none', () async {
      await SharedPreferencesAsync().setString('rental_providers', '[1,2');

      expect((await RentalProvidersService.loadPrefs()).groups, isEmpty);
    });
  });
}
