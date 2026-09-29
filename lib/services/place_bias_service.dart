import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../utils/place_bias.dart';

/// Stores how strongly place search leans towards the rider's position.
///
/// See [PlaceBias] for the values; [PlaceBias.off] means the position is not
/// sent at all.
class PlaceBiasService {
  const PlaceBiasService._();

  static final ValueNotifier<double> biasListenable = ValueNotifier<double>(
    PlaceBias.defaultValue,
  );

  static Future<double>? _inFlight;
  static bool _loaded = false;

  /// Loads once and caches. Concurrent callers share one read.
  static Future<double> load() async {
    if (_loaded) return biasListenable.value;
    return (_inFlight ??= _load());
  }

  static Future<double> _load() async {
    try {
      final stored = await SharedPreferencesAsync().getDouble(
        PrefsKeys.placeBias,
      );
      biasListenable.value = stored == null || stored < 0
          ? PlaceBias.defaultValue
          : stored;
    } catch (e, stackTrace) {
      developer.log(
        'Could not read the place bias, using the default',
        name: 'PlaceBiasService',
        error: e,
        stackTrace: stackTrace,
      );
      biasListenable.value = PlaceBias.defaultValue;
    } finally {
      _loaded = true;
      _inFlight = null;
    }
    return biasListenable.value;
  }

  static Future<void> save(double value) async {
    biasListenable.value = value;
    _loaded = true;
    final prefs = SharedPreferencesAsync();
    // The default is left unstored, so a better-measured default reaches
    // everyone who never moved the slider.
    if (PlaceBias.isDefault(value)) {
      await prefs.remove(PrefsKeys.placeBias);
    } else {
      await prefs.setDouble(PrefsKeys.placeBias, value);
    }
  }

  /// Forgets the cache so the next [load] reads from storage again.
  @visibleForTesting
  static void invalidate() {
    _loaded = false;
    _inFlight = null;
    biasListenable.value = PlaceBias.defaultValue;
  }
}
