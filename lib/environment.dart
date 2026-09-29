import 'package:flutter/foundation.dart';
import 'api/transitous_endpoint.dart';
import 'providers/backend_provider.dart';
import 'utils/app_version.dart';

class Environment {
  const Environment._();

  static const String appName = 'Transportia';
  static const String contactEmail = 'contact@wafler.one';
  static const String contactUrl = 'https://wafler.one';
  static const String privacyUrl = 'https://wafler.one/transportia/privacy';
  static const String termsUrl = 'https://wafler.one/transportia/terms';
  static const String sponsorUrl = 'http://wafler.one?ref=transportia';

  static const bool showBackendSettings = true;

  static String get transitousHost =>
      BackendProvider.instance?.host ?? BackendProvider.defaultHost;

  /// API version segment for [endpoint], honouring any per-endpoint override.
  ///
  /// Falls back to the endpoint's declared default when no [BackendProvider]
  /// exists yet, which is the case in tests that exercise services directly.
  static String versionFor(TransitousEndpoint endpoint) =>
      BackendProvider.instance?.versionFor(endpoint) ??
      endpoint.defaultVersion(BackendProvider.defaultApiVersion);

  /// Full request path for [endpoint], e.g. `/api/v6/map/trips`.
  static String pathFor(TransitousEndpoint endpoint) =>
      endpoint.requestPath(versionFor(endpoint));

  static String get planApiVersion => versionFor(TransitousEndpoint.plan);

  static String get tripApiVersion => versionFor(TransitousEndpoint.trip);

  static String get stopTimesApiVersion =>
      versionFor(TransitousEndpoint.stopTimes);

  static String get mapTripsApiVersion =>
      versionFor(TransitousEndpoint.mapTrips);

  static String get mapStopsApiVersion =>
      versionFor(TransitousEndpoint.mapStops);

  static String get geocodeApiVersion => versionFor(TransitousEndpoint.geocode);

  static String get transitousUserAgent =>
      '$appName/${AppVersion.current} (+$contactUrl; $contactEmail)';

  static Map<String, String> transitousHeaders({bool acceptJson = true}) {
    final headers = <String, String>{};
    if (!kIsWeb) {
      headers['User-Agent'] = transitousUserAgent;
    }
    if (acceptJson) {
      headers['accept'] = 'application/json';
    }
    return headers;
  }
}
