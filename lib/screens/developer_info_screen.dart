import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';
import '../models/saved_trip.dart';
import '../services/favorites_service.dart';
import '../services/recent_trips_service.dart';
import '../services/saved_places_service.dart';
import '../services/saved_trips_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_version.dart';
import '../utils/geo_utils.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/custom_card.dart';
import '../constants/prefs_keys.dart';
import '../theme/app_text.dart';

/// The metadata lines under every entry on this screen: coordinates, ids,
/// timestamps. Local rather than in [AppText] because this screen is the only
/// place that prints raw stored values, so the recipe means nothing elsewhere.
TextStyle get _metaLine =>
    TextStyle(fontSize: 12, color: AppColors.black.withValues(alpha: 0.55));

class DeveloperInfoScreen extends StatefulWidget {
  const DeveloperInfoScreen({super.key});

  @override
  State<DeveloperInfoScreen> createState() => _DeveloperInfoScreenState();
}

class _DeveloperInfoScreenState extends State<DeveloperInfoScreen> {
  static const Set<String> _prefsAllowList = {
    PrefsKeys.welcomeSeen,
    PrefsKeys.accentColor,
    PrefsKeys.mapStyle,
    PrefsKeys.appTheme,
    PrefsKeys.mapShowStops,
    PrefsKeys.mapQuickButton,
    PrefsKeys.mapShowVehicles,
    PrefsKeys.mapHideNonRtVehicles,
    PrefsKeys.mapShowTrain,
    PrefsKeys.mapShowMetro,
    PrefsKeys.mapShowTram,
    PrefsKeys.mapShowBus,
    PrefsKeys.mapShowFerry,
    PrefsKeys.mapShowLift,
    PrefsKeys.mapShowOther,
    PrefsKeys.lastGpsLat,
    PrefsKeys.lastGpsLng,
  };

  static const String _cacheLastOpenedKey = 'debug_cache_last_opened';
  static const String _cacheSavedSearchPlacesKey =
      'debug_saved_places_search_count';
  static const String _cacheSavedTimetablePlacesKey =
      'debug_saved_places_timetable_count';
  static const String _cacheFavoritesKey = 'debug_favorites_count';
  static const String _cacheRecentTripsKey = 'debug_recent_trips_count';
  static const String _cacheSavedTripsKey = 'debug_saved_trips_count';

  static const Set<String> _cacheAllowList = {
    _cacheLastOpenedKey,
    _cacheSavedSearchPlacesKey,
    _cacheSavedTimetablePlacesKey,
    _cacheFavoritesKey,
    _cacheRecentTripsKey,
    _cacheSavedTripsKey,
  };

  bool _isLoading = true;
  String? _errorMessage;
  List<SavedPlace> _savedSearchPlaces = [];
  List<SavedPlace> _savedTimetablePlaces = [];
  List<FavoritePlace> _favorites = [];
  List<SavedTrip> _recentTrips = [];
  List<SavedTrip> _savedTrips = [];
  Map<String, Object?> _storedPreferences = {};
  Map<String, Object?> _cachedPreferences = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    try {
      final prefs = SharedPreferencesAsync();
      final storedPrefs = await prefs.getAll(allowList: _prefsAllowList);

      final savedSearchPlaces = await SavedPlacesService.loadPlaces(
        bucket: SavedPlacesBucket.search,
      );
      final savedTimetablePlaces = await SavedPlacesService.loadPlaces(
        bucket: SavedPlacesBucket.timetable,
      );
      final favorites = await FavoritesService.getFavorites();
      final recentTrips = await RecentTripsService.getRecentTrips();
      final savedTrips = await SavedTripsService.getSavedTrips();

      final cache = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: _cacheAllowList,
        ),
      );
      await cache.setString(
        _cacheLastOpenedKey,
        DateTime.now().toIso8601String(),
      );
      await cache.setInt(_cacheSavedSearchPlacesKey, savedSearchPlaces.length);
      await cache.setInt(
        _cacheSavedTimetablePlacesKey,
        savedTimetablePlaces.length,
      );
      await cache.setInt(_cacheFavoritesKey, favorites.length);
      await cache.setInt(_cacheRecentTripsKey, recentTrips.length);
      await cache.setInt(_cacheSavedTripsKey, savedTrips.length);

      final cachedPrefs = <String, Object?>{};
      for (final key in cache.keys) {
        cachedPrefs[key] = cache.get(key);
      }

      if (!mounted) return;
      setState(() {
        _savedSearchPlaces = savedSearchPlaces;
        _savedTimetablePlaces = savedTimetablePlaces;
        _favorites = favorites;
        _recentTrips = recentTrips;
        _savedTrips = savedTrips;
        _storedPreferences = storedPrefs;
        _cachedPreferences = cachedPrefs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: Text('Loading…'))
        : _errorMessage != null
        ? Center(child: Text(_errorMessage!))
        : _buildSections();

    return AppPageScaffold(
      title: 'Developer Info',
      scrollable: true,
      body: content,
    );
  }

  Widget _buildSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'App',
          child: _keyValueList({
            'version': AppVersion.current,
            'saved_search_places': _savedSearchPlaces.length,
            'saved_timetable_places': _savedTimetablePlaces.length,
            'favorites': _favorites.length,
            'recent_trips': _recentTrips.length,
            'saved_trips': _savedTrips.length,
          }),
        ),
        _sectionCard(
          title: 'Stored Preferences',
          child: _keyValueList(_storedPreferences),
        ),
        _sectionCard(
          title: 'Saved Places (Search)',
          child: _savedSearchPlaces.isEmpty
              ? _emptyLabel('No saved places yet.')
              : _savedPlacesList(_savedSearchPlaces),
        ),
        _sectionCard(
          title: 'Saved Places (Timetables)',
          child: _savedTimetablePlaces.isEmpty
              ? _emptyLabel('No saved places yet.')
              : _savedPlacesList(_savedTimetablePlaces),
        ),
        _sectionCard(
          title: 'Favourites',
          child: _favorites.isEmpty
              ? _emptyLabel('No favourites saved.')
              : _favoritesList(_favorites),
        ),
        _sectionCard(
          title: 'Recent Trips',
          child: _recentTrips.isEmpty
              ? _emptyLabel('No recent trips saved.')
              : _recentTripsList(_recentTrips),
        ),
        _sectionCard(
          title: 'Saved Trips',
          child: _savedTrips.isEmpty
              ? _emptyLabel('No saved trips.')
              : _savedTripsList(_savedTrips),
        ),
        _sectionCard(
          title: 'Cached Info',
          child: _keyValueList(_cachedPreferences),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _emptyLabel(String message) {
    return Text(message, style: AppText.footnote);
  }

  Widget _keyValueList(Map<String, Object?> values) {
    if (values.isEmpty) {
      return _emptyLabel('No values found.');
    }
    final entries = values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          _keyValueRow(entries[i].key, entries[i].value),
          if (i != entries.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _keyValueRow(String key, Object? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            key,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            _formatValue(value),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  String _formatValue(Object? value) {
    if (value == null) return 'null';
    if (value is List<String>) {
      return value.isEmpty ? '[]' : value.join(', ');
    }
    return value.toString();
  }

  Widget _savedPlacesList(List<SavedPlace> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < places.length; i++) ...[
          _savedPlaceRow(places[i]),
          if (i != places.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _savedPlaceRow(SavedPlace place) {
    final meta = <String>[];
    if (place.city != null && place.city!.trim().isNotEmpty) {
      meta.add(place.city!.trim());
    }
    if (place.countryCode != null && place.countryCode!.trim().isNotEmpty) {
      meta.add(place.countryCode!.trim());
    }
    final metaLabel = meta.join(' • ');
    final coords = coordLabel(place.lat, place.lon, decimals: 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${place.name} (${place.type})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        if (metaLabel.isNotEmpty) Text(metaLabel, style: _metaLine),
        Text(coords, style: _metaLine),
        Text('Importance ${place.importance}', style: _metaLine),
      ],
    );
  }

  Widget _favoritesList(List<FavoritePlace> favorites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < favorites.length; i++) ...[
          _favoriteRow(favorites[i]),
          if (i != favorites.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _favoriteRow(FavoritePlace place) {
    final coords = coordLabel(place.lat, place.lon, decimals: 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        Text(coords, style: _metaLine),
        Text(
          'Icon ${place.iconName} • Added ${place.addedAt.toIso8601String()}',
          style: _metaLine,
        ),
      ],
    );
  }

  Widget _savedTripsList(List<SavedTrip> trips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < trips.length; i++) ...[
          _savedTripRow(trips[i]),
          if (i != trips.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _savedTripRow(SavedTrip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${trip.fromName} \u2192 ${trip.toName}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        Text(
          '${trip.departureTime.toIso8601String()} '
          '(saved ${trip.savedAt.toIso8601String()})',
          style: _metaLine,
        ),
        Text(
          trip.id,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.black.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _recentTripsList(List<SavedTrip> trips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < trips.length; i++) ...[
          _recentTripRow(trips[i]),
          if (i != trips.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _recentTripRow(SavedTrip trip) {
    final from =
        '${trip.fromName} (${trip.fromLat.toStringAsFixed(4)}, ${trip.fromLon.toStringAsFixed(4)})';
    final to =
        '${trip.toName} (${trip.toLat.toStringAsFixed(4)}, ${trip.toLon.toStringAsFixed(4)})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$from → $to',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        Text(
          'opened ${trip.savedAt.toIso8601String()} · '
          'departs ${trip.departureTime.toIso8601String()}',
          style: _metaLine,
        ),
      ],
    );
  }
}
