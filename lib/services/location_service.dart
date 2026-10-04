import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/prefs_keys.dart';

class LocationService {
  static const _kLastLatKey = PrefsKeys.lastGpsLat;
  static const _kLastLngKey = PrefsKeys.lastGpsLng;
  static Future<bool>? _pendingPermissionRequest;

  static Future<bool> hasPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  static Future<bool> ensurePermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    final pending = _pendingPermissionRequest;
    if (pending != null) return pending;
    final request = Permission.locationWhenInUse
        .request()
        .then((result) => result.isGranted)
        .catchError((_) => false);
    _pendingPermissionRequest = request;
    final granted = await request;
    _pendingPermissionRequest = null;
    return granted;
  }

  /// Read-only status checks, which never prompt: they are how settings
  /// explain why background tracking is unavailable.
  static Future<bool> hasLocationAlwaysPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Asks for "allow all the time" location and for notifications, which
  /// tracking needs to keep going from a notification once the app is in the
  /// background. Never throws; false on a refusal, so callers can quietly
  /// settle for tracking while the app is open.
  static Future<bool> ensureBackgroundPermission() async {
    try {
      if (!await ensurePermission()) return false;
      final background = await Permission.locationAlways.request();
      if (!background.isGranted) return false;
      final notifications = await Permission.notification.request();
      return notifications.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  static Future<Position?> lastKnownPosition() {
    return Geolocator.getLastKnownPosition();
  }

  static Future<Position> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  /// How long a position fix may take before an older one stands in.
  static const Duration _kFixTimeout = Duration(seconds: 5);

  /// A fresh fix, or failing that the last one the device knew, or the last
  /// one the app saved; null when there is none of them.
  static Future<LatLng?> currentOrLastKnownLatLng() async {
    try {
      final position = await currentPosition().timeout(_kFixTimeout);
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        final last = await lastKnownPosition();
        if (last != null) return LatLng(last.latitude, last.longitude);
      } catch (_) {}
      return loadLastLatLng();
    }
  }

  static Future<void> saveLastLatLng(LatLng v) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setDouble(_kLastLatKey, v.latitude);
    await prefs.setDouble(_kLastLngKey, v.longitude);
  }

  static Future<LatLng?> loadLastLatLng() async {
    final prefs = SharedPreferencesAsync();
    final lat = await prefs.getDouble(_kLastLatKey);
    final lng = await prefs.getDouble(_kLastLngKey);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}
