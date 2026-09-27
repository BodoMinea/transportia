import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../models/routing_options.dart';
import '../models/transitous/enums.dart';

/// Brings storage written by 1.0.3 up to what 1.0.4 expects.
///
/// Upgrade only. Android refuses a lower versionCode unless the app is
/// uninstalled first, which clears storage anyway, so there is no downgrade to
/// write.
class MigrateV103ToV104 {
  const MigrateV103ToV104._();

  /// The released version this migration reads storage from.
  static const String from = '1.0.3';

  /// Keys 1.0.3 wrote that 1.0.4 renamed. Left as literals: they are facts
  /// about a released build, not names this app still uses.
  static const String _oldWelcomeSeen = 'welcome_seen_v1';
  static const String _oldSavedPlacesSearch = 'saved_places_search_v1';
  static const String _oldSavedPlacesTimetable = 'saved_places_timetable_v1';

  /// Dropped in 1.0.4 along with the in-app update prompt.
  static const String _ignoredUpdateVersion = 'ignored_update_version';

  /// Something a used 1.0.3 install is certain to have written. Storage with
  /// none of these and no version stamp is a fresh install, not an old one.
  static const List<String> _traces = [
    _oldWelcomeSeen,
    PrefsKeys.favoritePlaces,
    PrefsKeys.recentTrips,
    _oldSavedPlacesSearch,
  ];

  /// The Transit options screen 1.0.3 shipped offered exactly this many modes,
  /// and wrote all of them out when nothing was deselected. That list means "no
  /// restriction", not "pin the search to the 28 modes that build knew".
  static const int _modeOptionCount = 28;

  static Future<bool> hasTraces(SharedPreferencesAsync prefs) async {
    for (final key in _traces) {
      if (await prefs.containsKey(key)) return true;
    }
    return false;
  }

  static Future<void> run(SharedPreferencesAsync prefs) async {
    await _renameBool(prefs, _oldWelcomeSeen, PrefsKeys.welcomeSeen);
    await _renameString(
      prefs,
      _oldSavedPlacesSearch,
      PrefsKeys.savedPlacesSearch,
    );
    await _renameString(
      prefs,
      _oldSavedPlacesTimetable,
      PrefsKeys.savedPlacesTimetable,
    );
    await _foldRoutingScalarsIntoBlob(prefs);
    await _dropRecentSearchPairs(prefs);
    await prefs.remove(_ignoredUpdateVersion);
  }

  /// 1.0.3 kept each recent search as a bare origin/destination pair; 1.0.4
  /// keeps the connection that was opened, as a saved trip. A pair has no
  /// connection to become one, and the places in it are already among the
  /// picker's recents, so the list starts again empty.
  ///
  /// Only a list still holding pairs is removed, so a rerun cannot touch
  /// anything 1.0.4 has since written under the same key.
  static Future<void> _dropRecentSearchPairs(
    SharedPreferencesAsync prefs,
  ) async {
    final encoded = await prefs.getString(PrefsKeys.recentTrips);
    if (encoded == null) return;

    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      decoded = null;
    }
    final holdsPairs =
        decoded is! List ||
        decoded.any(
          (entry) => entry is! Map || !entry.containsKey('itinerary'),
        );
    if (holdsPairs) await prefs.remove(PrefsKeys.recentTrips);
  }

  static Future<void> _renameBool(
    SharedPreferencesAsync prefs,
    String oldKey,
    String newKey,
  ) async {
    final value = await prefs.getBool(oldKey);
    if (value == null) return;
    await prefs.setBool(newKey, value);
    await prefs.remove(oldKey);
  }

  static Future<void> _renameString(
    SharedPreferencesAsync prefs,
    String oldKey,
    String newKey,
  ) async {
    final value = await prefs.getString(oldKey);
    if (value == null) return;
    await prefs.setString(newKey, value);
    await prefs.remove(oldKey);
  }

  /// 1.0.3 kept walking speed, transfer buffer and mode selection as three
  /// scalars; 1.0.4 keeps one JSON blob.
  ///
  /// Does nothing when the blob is already there, so a half-finished run picks
  /// up where it stopped rather than overwriting migrated settings.
  static Future<void> _foldRoutingScalarsIntoBlob(
    SharedPreferencesAsync prefs,
  ) async {
    if (await prefs.containsKey(PrefsKeys.routingOptions)) return;

    final speed = await prefs.getDouble(PrefsKeys.transitWalkingSpeed);
    final buffer = await prefs.getInt(PrefsKeys.transitTransferBuffer);
    final modes = await prefs.getStringList(PrefsKeys.transitSelectedModes);

    if (speed != null || buffer != null || modes != null) {
      final options = RoutingOptions.defaults.copyWith(
        walkingSpeedKmh: speed,
        additionalTransferTime: buffer == null
            ? null
            : Duration(minutes: buffer),
        transitModes: modes == null ? null : _modesFrom(modes),
      );
      await prefs.setString(
        PrefsKeys.routingOptions,
        jsonEncode(options.toJson()),
      );
    }

    await prefs.remove(PrefsKeys.transitWalkingSpeed);
    await prefs.remove(PrefsKeys.transitTransferBuffer);
    await prefs.remove(PrefsKeys.transitSelectedModes);
  }

  static List<TransitMode> _modesFrom(List<String> stored) {
    final modes = [
      for (final name in stored)
        if (TransitMode.fromWire(name) case final mode?) mode,
    ];
    return modes.length >= _modeOptionCount ? const [] : modes;
  }
}
