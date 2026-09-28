import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/nominatim_client.dart';
import '../api/transitous_endpoint.dart';
import '../constants/prefs_keys.dart';

class BackendProvider extends ChangeNotifier {
  static const String defaultHost = 'api.transitous.org';

  static BackendProvider? _instance;
  static BackendProvider? get instance => _instance;

  String _host = defaultHost;
  bool _placeDetailsEnabled = true;
  String _nominatimHost = NominatimClient.defaultHost;
  String? _apiVersionOverride;
  final Map<String, String> _endpointVersions = {};

  String get host => _host;

  /// Whether tapping a result on the map asks OpenStreetMap, through
  /// Nominatim, for its address, opening hours and the like. On unless
  /// turned off: nothing about the rider is sent, only which place.
  bool get placeDetailsEnabled => _placeDetailsEnabled;

  /// Nominatim's usage policy asks that an app can be pointed at another
  /// server without an update; this is where.
  String get nominatimHost => _nominatimHost;
  bool get isCustomNominatimHost =>
      _nominatimHost != NominatimClient.defaultHost;
  bool get isCustomHost => _host != defaultHost;

  String get apiVersion =>
      _apiVersionOverride ?? _computeDefaultApiVersion(_host);
  bool get isCustomApiVersion => _apiVersionOverride != null;

  /// Version segment to use for [endpoint]: an explicit per-endpoint override
  /// if the user set one, otherwise whatever the endpoint declares as its
  /// default for the current main version.
  String versionFor(TransitousEndpoint endpoint) =>
      _endpointVersions[endpoint.prefKey] ?? defaultVersionFor(endpoint);

  /// Version [endpoint] uses when no override is set.
  String defaultVersionFor(TransitousEndpoint endpoint) =>
      endpoint.defaultVersion(apiVersion);

  bool get hasEndpointOverrides => _endpointVersions.isNotEmpty;
  bool isEndpointOverridden(TransitousEndpoint endpoint) =>
      _endpointVersions.containsKey(endpoint.prefKey);
  String? endpointVersionOverride(TransitousEndpoint endpoint) =>
      _endpointVersions[endpoint.prefKey];

  static String _computeDefaultApiVersion(String host) =>
      host.contains('transitous') ? 'v6' : 'v1';

  static String _endpointPrefKey(String key) =>
      'transitous_api_version_endpoint_$key';

  BackendProvider() {
    _instance = this;
    _load();
  }

  Future<void> _load() async {
    final prefs = SharedPreferencesAsync();
    final savedHost = await prefs.getString(PrefsKeys.transitousHost);
    final savedVersion = await prefs.getString(PrefsKeys.transitousApiVersion);
    if (savedHost != null && savedHost.isNotEmpty) _host = savedHost;
    _placeDetailsEnabled =
        await prefs.getBool(PrefsKeys.placeDetailsEnabled) ?? true;
    final savedNominatim = await prefs.getString(PrefsKeys.nominatimHost);
    if (savedNominatim != null && savedNominatim.isNotEmpty) {
      _nominatimHost = savedNominatim;
    }
    if (savedVersion != null && savedVersion.isNotEmpty) {
      _apiVersionOverride = savedVersion;
    }
    for (final endpoint in TransitousEndpoint.values) {
      final v = await prefs.getString(_endpointPrefKey(endpoint.prefKey));
      if (v != null && v.isNotEmpty) _endpointVersions[endpoint.prefKey] = v;
    }
    notifyListeners();
  }

  Future<void> setHost(String host) async {
    final trimmed = host.trim();
    final effective = trimmed.isEmpty ? defaultHost : trimmed;
    if (effective == _host) return;
    _host = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_host == defaultHost) {
      await prefs.remove(PrefsKeys.transitousHost);
    } else {
      await prefs.setString(PrefsKeys.transitousHost, _host);
    }
  }

  Future<void> resetHost() => setHost(defaultHost);

  Future<void> setPlaceDetailsEnabled(bool enabled) async {
    if (enabled == _placeDetailsEnabled) return;
    _placeDetailsEnabled = enabled;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (enabled) {
      await prefs.remove(PrefsKeys.placeDetailsEnabled);
    } else {
      await prefs.setBool(PrefsKeys.placeDetailsEnabled, false);
    }
  }

  Future<void> setNominatimHost(String host) async {
    final trimmed = host.trim();
    final effective = trimmed.isEmpty ? NominatimClient.defaultHost : trimmed;
    if (effective == _nominatimHost) return;
    _nominatimHost = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_nominatimHost == NominatimClient.defaultHost) {
      await prefs.remove(PrefsKeys.nominatimHost);
    } else {
      await prefs.setString(PrefsKeys.nominatimHost, _nominatimHost);
    }
  }

  Future<void> setApiVersion(String version) async {
    final trimmed = version.trim();
    final computedDefault = _computeDefaultApiVersion(_host);
    final effective = trimmed.isEmpty || trimmed == computedDefault
        ? null
        : trimmed;
    if (effective == _apiVersionOverride) return;
    _apiVersionOverride = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_apiVersionOverride == null) {
      await prefs.remove(PrefsKeys.transitousApiVersion);
    } else {
      await prefs.setString(
        PrefsKeys.transitousApiVersion,
        _apiVersionOverride!,
      );
    }
  }

  Future<void> resetApiVersion() => setApiVersion('');

  Future<void> setEndpointVersion(
    TransitousEndpoint endpoint,
    String version,
  ) async {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return resetEndpointVersion(endpoint);
    if (_endpointVersions[endpoint.prefKey] == trimmed) return;
    _endpointVersions[endpoint.prefKey] = trimmed;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_endpointPrefKey(endpoint.prefKey), trimmed);
  }

  Future<void> resetEndpointVersion(TransitousEndpoint endpoint) async {
    if (!_endpointVersions.containsKey(endpoint.prefKey)) return;
    _endpointVersions.remove(endpoint.prefKey);
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_endpointPrefKey(endpoint.prefKey));
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }
}
