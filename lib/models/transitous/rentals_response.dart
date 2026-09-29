import '../itinerary.dart' show EncodedPolyline;
import 'enums.dart';
import 'json.dart';
import 'rental.dart';

/// Bounding box as `[minLon, minLat, maxLon, maxLat]`.
class GeoBounds {
  const GeoBounds({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  /// Parses the flat four-element array MOTIS uses, returning null when it is
  /// absent or the wrong length.
  static GeoBounds? fromJson(Object? value) {
    if (value is! List || value.length < 4) return null;
    final values = value.map(asDouble).toList();
    if (values.any((v) => v == null)) return null;
    return GeoBounds(
      minLon: values[0]!,
      minLat: values[1]!,
      maxLon: values[2]!,
      maxLat: values[3]!,
    );
  }
}

/// A group of rental providers presented to riders as one brand.
class RentalProviderGroup {
  const RentalProviderGroup({
    required this.id,
    required this.name,
    this.providers = const [],
    this.formFactors = const [],
  });

  final String id;
  final String name;

  /// Ids of the providers in this group.
  final List<String> providers;

  final List<RentalFormFactor> formFactors;

  factory RentalProviderGroup.fromJson(Map<String, dynamic> json) =>
      RentalProviderGroup(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? '',
        providers: asStringList(json['providers']),
        formFactors: _formFactors(json['formFactors']),
      );

  /// The wire shape, so a cached copy reads back through [fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'providers': providers,
    'formFactors': [for (final factor in formFactors) factor.wireName],
  };
}

/// A single vehicle-sharing operator.
class RentalProvider {
  const RentalProvider({
    required this.id,
    required this.name,
    required this.groupId,
    this.operator,
    this.url,
    this.purchaseUrl,
    this.bbox,
    this.vehicleTypes = const [],
  });

  final String id;
  final String name;
  final String groupId;

  /// Legal operator, often with a postal address.
  final String? operator;

  final String? url;
  final String? purchaseUrl;

  /// Area the provider serves.
  final GeoBounds? bbox;

  final List<RentalVehicleType> vehicleTypes;

  factory RentalProvider.fromJson(Map<String, dynamic> json) => RentalProvider(
    id: asString(json['id']) ?? '',
    name: asString(json['name']) ?? '',
    groupId: asString(json['groupId']) ?? '',
    operator: asString(json['operator']),
    url: asString(json['url']),
    purchaseUrl: asString(json['purchaseUrl']),
    bbox: GeoBounds.fromJson(json['bbox']),
    vehicleTypes: asList(json['vehicleTypes'], RentalVehicleType.fromJson),
  );
}

/// A docking station.
class RentalStation {
  const RentalStation({
    required this.id,
    required this.providerId,
    required this.providerGroupId,
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.crossStreet,
    this.rentalUriAndroid,
    this.rentalUriIOS,
    this.rentalUriWeb,
    this.isRenting = false,
    this.isReturning = false,
    this.numVehiclesAvailable,
    this.numDocksAvailable,
    this.formFactors = const [],
  });

  final String id;
  final String providerId;
  final String providerGroupId;
  final String name;
  final double lat;
  final double lon;
  final String? address;
  final String? crossStreet;
  final String? rentalUriAndroid;
  final String? rentalUriIOS;
  final String? rentalUriWeb;

  /// Whether the station is currently handing out vehicles.
  final bool isRenting;

  /// Whether the station is currently accepting returns.
  final bool isReturning;

  final int? numVehiclesAvailable;
  final int? numDocksAvailable;
  final List<RentalFormFactor> formFactors;

  factory RentalStation.fromJson(Map<String, dynamic> json) => RentalStation(
    id: asString(json['id']) ?? '',
    providerId: asString(json['providerId']) ?? '',
    providerGroupId: asString(json['providerGroupId']) ?? '',
    name: asString(json['name']) ?? '',
    lat: asDouble(json['lat']) ?? 0.0,
    lon: asDouble(json['lon']) ?? 0.0,
    address: asString(json['address']),
    crossStreet: asString(json['crossStreet']),
    rentalUriAndroid: asString(json['rentalUriAndroid']),
    rentalUriIOS: asString(json['rentalUriIOS']),
    rentalUriWeb: asString(json['rentalUriWeb']),
    isRenting: asBool(json['isRenting']) ?? false,
    isReturning: asBool(json['isReturning']) ?? false,
    numVehiclesAvailable: asInt(json['numVehiclesAvailable']),
    numDocksAvailable: asInt(json['numDocksAvailable']),
    formFactors: _formFactors(json['formFactors']),
  );
}

/// A free-floating or docked vehicle.
class RentalVehicle {
  const RentalVehicle({
    required this.id,
    required this.providerId,
    required this.providerGroupId,
    required this.lat,
    required this.lon,
    this.typeId,
    this.formFactor,
    this.propulsionType,
    this.returnConstraint,
    this.stationId,
    this.homeStationId,
    this.isReserved = false,
    this.isDisabled = false,
    this.rentalUriAndroid,
    this.rentalUriIOS,
    this.rentalUriWeb,
  });

  final String id;
  final String providerId;
  final String providerGroupId;
  final double lat;
  final double lon;

  /// Id of the matching [RentalVehicleType] on the provider.
  final String? typeId;

  final RentalFormFactor? formFactor;
  final RentalPropulsionType? propulsionType;
  final RentalReturnConstraint? returnConstraint;

  /// Station the vehicle is docked at, empty when free-floating.
  final String? stationId;

  /// Station it must be returned to, for roundtrip systems.
  final String? homeStationId;

  final bool isReserved;
  final bool isDisabled;
  final String? rentalUriAndroid;
  final String? rentalUriIOS;
  final String? rentalUriWeb;

  /// True when the vehicle can actually be taken right now.
  bool get isAvailable => !isReserved && !isDisabled;

  factory RentalVehicle.fromJson(Map<String, dynamic> json) => RentalVehicle(
    id: asString(json['id']) ?? '',
    providerId: asString(json['providerId']) ?? '',
    providerGroupId: asString(json['providerGroupId']) ?? '',
    lat: asDouble(json['lat']) ?? 0.0,
    lon: asDouble(json['lon']) ?? 0.0,
    typeId: asString(json['typeId']),
    formFactor: RentalFormFactor.fromWire(json['formFactor']),
    propulsionType: RentalPropulsionType.fromWire(json['propulsionType']),
    returnConstraint: RentalReturnConstraint.fromWire(json['returnConstraint']),
    stationId: asString(json['stationId']),
    homeStationId: asString(json['homeStationId']),
    isReserved: asBool(json['isReserved']) ?? false,
    isDisabled: asBool(json['isDisabled']) ?? false,
    rentalUriAndroid: asString(json['rentalUriAndroid']),
    rentalUriIOS: asString(json['rentalUriIOS']),
    rentalUriWeb: asString(json['rentalUriWeb']),
  );
}

/// What a provider allows inside a geofenced area.
class RentalZoneRule {
  const RentalZoneRule({
    this.vehicleTypeIndexes = const [],
    this.rideStartAllowed = true,
    this.rideEndAllowed = true,
    this.rideThroughAllowed = true,
    this.stationParking = false,
  });

  /// Indexes into the provider's `vehicleTypes` this rule applies to.
  final List<int> vehicleTypeIndexes;

  final bool rideStartAllowed;
  final bool rideEndAllowed;
  final bool rideThroughAllowed;

  /// True when vehicles may only be parked at a station inside this zone.
  final bool stationParking;

  factory RentalZoneRule.fromJson(Map<String, dynamic> json) => RentalZoneRule(
    vehicleTypeIndexes: json['vehicleTypeIdxs'] is List
        ? [
            for (final v in json['vehicleTypeIdxs'] as List)
              if (asInt(v) case final i?) i,
          ]
        : const [],
    rideStartAllowed: asBool(json['rideStartAllowed']) ?? true,
    rideEndAllowed: asBool(json['rideEndAllowed']) ?? true,
    rideThroughAllowed: asBool(json['rideThroughAllowed']) ?? true,
    stationParking: asBool(json['stationParking']) ?? false,
  );
}

/// A geofenced area with its own rules, e.g. a no-parking zone.
class RentalZone {
  const RentalZone({
    required this.providerId,
    required this.providerGroupId,
    this.name,
    this.bbox,
    this.area = const [],
    this.rules = const [],
  });

  final String providerId;
  final String providerGroupId;
  final String? name;
  final GeoBounds? bbox;

  /// Polygons making up the zone, each an outer ring followed by its holes.
  final List<List<EncodedPolyline>> area;

  final List<RentalZoneRule> rules;

  factory RentalZone.fromJson(Map<String, dynamic> json) {
    final area = json['area'];
    return RentalZone(
      providerId: asString(json['providerId']) ?? '',
      providerGroupId: asString(json['providerGroupId']) ?? '',
      name: asString(json['name']),
      bbox: GeoBounds.fromJson(json['bbox']),
      area: area is! List
          ? const []
          : List.unmodifiable([
              for (final polygon in area)
                asList(polygon, EncodedPolyline.fromJson),
            ]),
      rules: asList(json['rules'], RentalZoneRule.fromJson),
    );
  }
}

/// Response of `/rentals`. Each list is only populated when the matching
/// `with*` parameter was requested.
class RentalsResponse {
  const RentalsResponse({
    this.providerGroups = const [],
    this.providers = const [],
    this.stations = const [],
    this.vehicles = const [],
    this.zones = const [],
  });

  final List<RentalProviderGroup> providerGroups;
  final List<RentalProvider> providers;
  final List<RentalStation> stations;
  final List<RentalVehicle> vehicles;
  final List<RentalZone> zones;

  factory RentalsResponse.fromJson(Map<String, dynamic> json) =>
      RentalsResponse(
        providerGroups: asList(
          json['providerGroups'],
          RentalProviderGroup.fromJson,
        ),
        providers: asList(json['providers'], RentalProvider.fromJson),
        stations: asList(json['stations'], RentalStation.fromJson),
        vehicles: asList(json['vehicles'], RentalVehicle.fromJson),
        zones: asList(json['zones'], RentalZone.fromJson),
      );
}

List<RentalFormFactor> _formFactors(Object? raw) {
  if (raw is! List) return const [];
  return List.unmodifiable([
    for (final entry in raw)
      if (RentalFormFactor.fromWire(entry) case final factor?) factor,
  ]);
}
