import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/endpoints/misc_endpoints.dart';
import '../constants/prefs_keys.dart';
import '../environment.dart';
import '../models/rental_provider_prefs.dart';
import '../models/transitous/rentals_response.dart';

/// The rental providers the rider has an account with, and the server's list
/// of providers to pick them from.
///
/// The picks decide what is sent; the list is only for showing names. So an
/// out-of-date or missing list never changes a search.
class RentalProvidersService {
  const RentalProvidersService._();

  /// How long the provider list is trusted before it is fetched again. It
  /// changes when Transitous adds a feed, which is rare; showing yesterday's
  /// list costs nothing.
  static const Duration catalogueMaxAge = Duration(days: 7);

  /// How far around the rider a group counts as "near you".
  static const double _kNearbyRadiusMetres = 50000;

  /// Decimal places a position is rounded to before asking what is nearby:
  /// two is about a kilometre, far finer than the radius.
  static const int _kNearbyKeyDecimals = 2;

  static final ValueNotifier<RentalProviderPrefs> prefsListenable =
      ValueNotifier<RentalProviderPrefs>(RentalProviderPrefs.none);

  /// Every group the server lists, or null while none has been fetched for
  /// the current host.
  static final ValueNotifier<List<RentalProviderGroup>?> catalogueListenable =
      ValueNotifier<List<RentalProviderGroup>?>(null);

  static Future<RentalProviderPrefs>? _prefsInFlight;
  static bool _prefsLoaded = false;

  static Future<void>? _catalogueInFlight;
  static String? _catalogueHost;
  static DateTime? _catalogueFetchedAt;

  static final Map<String, Set<String>> _nearby = {};

  // --- The rider's picks ---------------------------------------------------

  static Future<RentalProviderPrefs> loadPrefs() async {
    if (_prefsLoaded) return prefsListenable.value;
    return (_prefsInFlight ??= _loadPrefs());
  }

  static Future<RentalProviderPrefs> _loadPrefs() async {
    try {
      final stored = await SharedPreferencesAsync().getString(
        PrefsKeys.rentalProviders,
      );
      final decoded = stored == null ? null : json.decode(stored);
      prefsListenable.value = decoded is Map<String, dynamic>
          ? RentalProviderPrefs.fromJson(decoded)
          : RentalProviderPrefs.none;
    } catch (e, stackTrace) {
      developer.log(
        'Could not read rental providers, using none',
        name: 'RentalProvidersService',
        error: e,
        stackTrace: stackTrace,
      );
      prefsListenable.value = RentalProviderPrefs.none;
    } finally {
      _prefsLoaded = true;
      _prefsInFlight = null;
    }
    return prefsListenable.value;
  }

  static Future<void> savePrefs(RentalProviderPrefs prefs) async {
    prefsListenable.value = prefs;
    _prefsLoaded = true;
    await SharedPreferencesAsync().setString(
      PrefsKeys.rentalProviders,
      json.encode(prefs.toJson()),
    );
  }

  static Future<void> add(PickedProviderGroup group) async =>
      savePrefs((await loadPrefs()).add(group));

  static Future<void> remove(String id) async =>
      savePrefs((await loadPrefs()).remove(id));

  static Future<void> setLimit(bool limit) async =>
      savePrefs((await loadPrefs()).withLimit(limit));

  /// The provider groups a search should keep to, or none for any.
  static Future<List<String>> activeGroupIds() async =>
      (await loadPrefs()).activeGroupIds;

  // --- The server's list --------------------------------------------------

  /// Publishes the stored list at once, and fetches a fresh one when it is
  /// missing, older than [catalogueMaxAge], or from another host.
  ///
  /// A failed fetch keeps whatever was there. Concurrent callers share one
  /// request.
  static Future<void> ensureCatalogue({DateTime? now}) =>
      _catalogueInFlight ??= _ensureCatalogue(
        now ?? DateTime.now(),
      ).whenComplete(() => _catalogueInFlight = null);

  static Future<void> _ensureCatalogue(DateTime now) async {
    final host = Environment.transitousHost;
    if (_catalogueHost != host) await _readCachedCatalogue(host);
    final fetchedAt = _catalogueFetchedAt;
    final fresh =
        catalogueListenable.value != null &&
        fetchedAt != null &&
        now.difference(fetchedAt) < catalogueMaxAge;
    if (fresh) return;

    try {
      final response = await RentalsEndpoint.rentals(withProviders: false);
      final groups = [
        for (final group in response.providerGroups)
          // One group comes without an id, and the server takes groups by
          // id, so it cannot be picked.
          if (group.id.isNotEmpty) group,
      ];
      catalogueListenable.value = groups;
      _catalogueHost = host;
      _catalogueFetchedAt = now;
      await SharedPreferencesAsync().setString(
        PrefsKeys.rentalCatalogue,
        json.encode({
          'host': host,
          'fetchedAt': now.toUtc().toIso8601String(),
          'groups': [for (final group in groups) group.toJson()],
        }),
      );
    } catch (e) {
      developer.log(
        'Could not fetch rental providers, keeping the stored list',
        name: 'RentalProvidersService',
        error: e,
      );
    }
  }

  static Future<void> _readCachedCatalogue(String host) async {
    _catalogueHost = host;
    _catalogueFetchedAt = null;
    catalogueListenable.value = null;
    _nearby.clear();
    try {
      final stored = await SharedPreferencesAsync().getString(
        PrefsKeys.rentalCatalogue,
      );
      if (stored == null) return;
      final decoded = json.decode(stored);
      if (decoded is! Map<String, dynamic> || decoded['host'] != host) return;
      final groups = decoded['groups'];
      if (groups is! List) return;
      catalogueListenable.value = [
        for (final entry in groups)
          if (entry is Map<String, dynamic>)
            RentalProviderGroup.fromJson(entry),
      ];
      _catalogueFetchedAt = DateTime.tryParse(
        decoded['fetchedAt'] as String? ?? '',
      );
    } catch (e) {
      developer.log(
        'Could not read the stored provider list',
        name: 'RentalProvidersService',
        error: e,
      );
    }
  }

  /// Ids of the groups the server places around [position], to offer them
  /// first. Empty when it cannot say.
  ///
  /// Kept for the session only: it is a ranking hint, and a stale one does
  /// no harm. The caller decides whether the rider's position may be sent.
  static Future<Set<String>> nearbyGroupIds(LatLng position) async {
    final key =
        '${position.latitude.toStringAsFixed(_kNearbyKeyDecimals)},'
        '${position.longitude.toStringAsFixed(_kNearbyKeyDecimals)}';
    final known = _nearby[key];
    if (known != null) return known;
    try {
      final response = await RentalsEndpoint.rentals(
        pointLat: position.latitude,
        pointLon: position.longitude,
        radius: _kNearbyRadiusMetres,
        // Each defaults to true once an area is given, and together they
        // are megabytes of stations, vehicles and zones.
        withProviders: false,
        withStations: false,
        withVehicles: false,
        withZones: false,
      );
      return _nearby[key] = {
        for (final group in response.providerGroups)
          if (group.id.isNotEmpty) group.id,
      };
    } catch (e) {
      developer.log(
        'Could not find nearby rental providers',
        name: 'RentalProvidersService',
        error: e,
      );
      return const {};
    }
  }

  /// Forgets everything held in memory, so the next calls read storage again.
  @visibleForTesting
  static void invalidate() {
    _prefsLoaded = false;
    _prefsInFlight = null;
    prefsListenable.value = RentalProviderPrefs.none;
    _catalogueInFlight = null;
    _catalogueHost = null;
    _catalogueFetchedAt = null;
    catalogueListenable.value = null;
    _nearby.clear();
  }
}
