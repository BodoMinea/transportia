import '../../models/transitous/rentals_response.dart';
import '../../models/transitous/route_info.dart';
import '../../models/transitous/server_config.dart';
import '../query.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// `/rentals` — vehicle-sharing providers, stations, vehicles and zones.
class RentalsEndpoint {
  const RentalsEndpoint._();

  /// Give either a bounding box or a [pointLat]/[pointLon] with a [radius].
  ///
  /// With no area and no provider filter, only the providers come back. Once
  /// an area or a filter is given, stations, vehicles and zones default to
  /// included: set the `with*` flags to false to leave them out, or a city's
  /// worth of vehicles comes back. [withProviders] false drops the provider
  /// details and keeps just the groups.
  ///
  /// Coordinates are `lat,lon`. The semicolon form is accepted without error
  /// but answers with providers from the wrong region, so it must not be used
  /// here.
  static Future<RentalsResponse> rentals({
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    double? pointLat,
    double? pointLon,
    double? radius,
    List<String> providerGroups = const [],
    List<String> providers = const [],
    bool? withProviders,
    bool? withStations,
    bool? withVehicles,
    bool? withZones,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.rentals,
      {
        'min': minLat == null || minLon == null
            ? null
            : Q.latLonComma(minLat, minLon),
        'max': maxLat == null || maxLon == null
            ? null
            : Q.latLonComma(maxLat, maxLon),
        'point': pointLat == null || pointLon == null
            ? null
            : Q.latLonComma(pointLat, pointLon),
        'radius': Q.number(radius),
        'providerGroups': Q.csv(providerGroups),
        'providers': Q.csv(providers),
        'withProviders': Q.boolean(withProviders),
        'withStations': Q.boolean(withStations),
        'withVehicles': Q.boolean(withVehicles),
        'withZones': Q.boolean(withZones),
      },
      (json) => RentalsResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// `/health` — which optional data feeds the server has live.
class HealthEndpoint {
  const HealthEndpoint._();

  static Future<HealthStatus> health({TransitousClient? client}) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.health,
      const {},
      (json) => HealthStatus.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// `/debug/transfers` — every transfer computed out of a stop, per profile.
///
/// Answers 404 for an id it does not recognise, so a failure here usually
/// means the stop id was wrong rather than that the endpoint is unavailable.
class DebugEndpoint {
  const DebugEndpoint._();

  /// [stopId] is the feed-prefixed form, e.g.
  /// `de-DELFI_de:11000:900100003`.
  static Future<TransfersDebugResponse> transfers({
    required String stopId,
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.debugTransfers,
      {'id': stopId},
      (json) => TransfersDebugResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}
