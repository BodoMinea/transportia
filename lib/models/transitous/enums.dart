/// Enum types from the MOTIS API.
///
/// Every enum parses leniently. The spec states outright that experimental
/// fields change "without version bumps", and `Mode` already carries four
/// deprecated aliases, so an unrecognised value is a normal event rather than
/// a bug: [fromWire] returns null and each model picks its own fallback.
library;

/// Implemented by every enum here so [fromWire] can be generic.
mixin WireEnum on Enum {
  String get wireName;
}

/// Returns the member of [values] whose `wireName` is [raw], or null when
/// [raw] is absent or unrecognised.
T? enumFromWire<T extends WireEnum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.wireName == raw) return value;
  }
  return null;
}

/// Travel mode of a leg, and the value accepted by the `*Modes` parameters.
enum TransitMode with WireEnum {
  walk('WALK'),
  bike('BIKE'),
  rental('RENTAL'),
  car('CAR'),
  hgv('HGV'),
  carParking('CAR_PARKING'),
  carDropoff('CAR_DROPOFF'),
  odm('ODM'),
  rideSharing('RIDE_SHARING'),
  flex('FLEX'),

  /// Expands to every transit mode server-side.
  transit('TRANSIT'),
  tram('TRAM'),
  subway('SUBWAY'),
  ferry('FERRY'),
  airplane('AIRPLANE'),
  bus('BUS'),
  coach('COACH'),

  /// Expands to the six rail modes server-side.
  rail('RAIL'),
  highspeedRail('HIGHSPEED_RAIL'),
  longDistance('LONG_DISTANCE'),
  nightRail('NIGHT_RAIL'),
  regionalRail('REGIONAL_RAIL'),
  suburban('SUBURBAN'),
  funicular('FUNICULAR'),
  aerialLift('AERIAL_LIFT'),
  other('OTHER'),

  debugBusRoute('DEBUG_BUS_ROUTE'),
  debugRailwayRoute('DEBUG_RAILWAY_ROUTE'),
  debugFerryRoute('DEBUG_FERRY_ROUTE'),

  /// Deprecated upstream: the server maps it to [regionalRail].
  regionalFastRail('REGIONAL_FAST_RAIL'),

  /// Deprecated upstream alias of [aerialLift] (an upstream typo).
  arealLift('AREAL_LIFT'),

  /// Deprecated upstream alias of [subway].
  metro('METRO'),

  /// Deprecated upstream alias of [aerialLift].
  cableCar('CABLE_CAR');

  const TransitMode(this.wireName);

  @override
  final String wireName;

  static TransitMode? fromWire(Object? raw) => enumFromWire(values, raw);

  /// True for modes routed over the street network rather than a timetable.
  bool get isStreetMode => const {
    walk,
    bike,
    rental,
    car,
    hgv,
    carParking,
    carDropoff,
  }.contains(this);

  /// Mainline trains from regional services up, and the generic `RAIL` a
  /// feed uses when it does not say which. They call at stations large
  /// enough that changing between them is a walk between platforms.
  bool get isRegionalOrLongerRail => const {
    rail,
    highspeedRail,
    longDistance,
    nightRail,
    regionalRail,
    regionalFastRail,
  }.contains(this);

  /// Any train, the suburban ones included.
  bool get isTrain => isRegionalOrLongerRail || this == suburban;

  /// Modes that run to numbered platforms, where a missing platform is a gap
  /// in the data rather than the mode simply having none.
  bool get runsToNumberedPlatforms =>
      isTrain || const {subway, metro, tram}.contains(this);
}

/// Penalty applied to inclines when routing street legs.
enum ElevationCosts with WireEnum {
  none('NONE'),
  low('LOW'),
  high('HIGH');

  const ElevationCosts(this.wireName);

  @override
  final String wireName;

  static ElevationCosts? fromWire(Object? raw) => enumFromWire(values, raw);
}

/// How real-time data is applied to a search.
///
/// Note there is no `FULL`: the server rejects it with
/// `enum RealtimeModeEnum: unknown value FULL`.
enum RealtimeMode with WireEnum {
  off('OFF'),
  annotationOnly('REALTIME_ANNOTATION_ONLY'),
  realtime('REALTIME');

  const RealtimeMode(this.wireName);

  @override
  final String wireName;

  static RealtimeMode? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum PedestrianProfile with WireEnum {
  foot('FOOT'),
  wheelchair('WHEELCHAIR');

  const PedestrianProfile(this.wireName);

  @override
  final String wireName;

  static PedestrianProfile? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum VertexType with WireEnum {
  normal('NORMAL'),
  bikeshare('BIKESHARE'),
  transit('TRANSIT');

  const VertexType(this.wireName);

  @override
  final String wireName;

  static VertexType? fromWire(Object? raw) => enumFromWire(values, raw);
}

/// What a geocoder match refers to.
enum LocationType with WireEnum {
  address('ADDRESS'),
  place('PLACE'),
  stop('STOP');

  const LocationType(this.wireName);

  @override
  final String wireName;

  static LocationType? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum WheelchairAccessibility with WireEnum {
  accessible('ACCESSIBLE'),
  notAccessible('NOT_ACCESSIBLE');

  const WheelchairAccessibility(this.wireName);

  @override
  final String wireName;

  static WheelchairAccessibility? fromWire(Object? raw) =>
      enumFromWire(values, raw);
}

enum Reservation with WireEnum {
  none('NONE'),
  compulsory('COMPULSORY');

  const Reservation(this.wireName);

  @override
  final String wireName;

  static Reservation? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum PickupDropoffType with WireEnum {
  normal('NORMAL'),
  notAllowed('NOT_ALLOWED');

  const PickupDropoffType(this.wireName);

  @override
  final String wireName;

  static PickupDropoffType? fromWire(Object? raw) => enumFromWire(values, raw);
}

/// Turn instruction for a walking or cycling step.
enum StepDirection with WireEnum {
  depart('DEPART'),
  hardLeft('HARD_LEFT'),
  left('LEFT'),
  slightlyLeft('SLIGHTLY_LEFT'),
  continueStraight('CONTINUE'),
  slightlyRight('SLIGHTLY_RIGHT'),
  right('RIGHT'),
  hardRight('HARD_RIGHT'),
  circleClockwise('CIRCLE_CLOCKWISE'),
  circleCounterclockwise('CIRCLE_COUNTERCLOCKWISE'),
  stairs('STAIRS'),
  elevator('ELEVATOR'),
  uturnLeft('UTURN_LEFT'),
  uturnRight('UTURN_RIGHT');

  const StepDirection(this.wireName);

  @override
  final String wireName;

  static StepDirection? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum RentalFormFactor with WireEnum {
  bicycle('BICYCLE'),
  cargoBicycle('CARGO_BICYCLE'),
  car('CAR'),
  moped('MOPED'),
  scooterStanding('SCOOTER_STANDING'),
  scooterSeated('SCOOTER_SEATED'),
  other('OTHER');

  const RentalFormFactor(this.wireName);

  @override
  final String wireName;

  static RentalFormFactor? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum RentalPropulsionType with WireEnum {
  human('HUMAN'),
  electricAssist('ELECTRIC_ASSIST'),
  electric('ELECTRIC'),
  combustion('COMBUSTION'),
  combustionDiesel('COMBUSTION_DIESEL'),
  hybrid('HYBRID'),
  plugInHybrid('PLUG_IN_HYBRID'),
  hydrogenFuelCell('HYDROGEN_FUEL_CELL');

  const RentalPropulsionType(this.wireName);

  @override
  final String wireName;

  static RentalPropulsionType? fromWire(Object? raw) =>
      enumFromWire(values, raw);
}

enum RentalReturnConstraint with WireEnum {
  none('NONE'),
  anyStation('ANY_STATION'),
  roundtripStation('ROUNDTRIP_STATION');

  const RentalReturnConstraint(this.wireName);

  @override
  final String wireName;

  static RentalReturnConstraint? fromWire(Object? raw) =>
      enumFromWire(values, raw);
}

enum AlertCause with WireEnum {
  unknownCause('UNKNOWN_CAUSE'),
  otherCause('OTHER_CAUSE'),
  technicalProblem('TECHNICAL_PROBLEM'),
  strike('STRIKE'),
  demonstration('DEMONSTRATION'),
  accident('ACCIDENT'),
  holiday('HOLIDAY'),
  weather('WEATHER'),
  maintenance('MAINTENANCE'),
  construction('CONSTRUCTION'),
  policeActivity('POLICE_ACTIVITY'),
  medicalEmergency('MEDICAL_EMERGENCY'),
  specialEvent('SPECIAL_EVENT');

  const AlertCause(this.wireName);

  @override
  final String wireName;

  static AlertCause? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum AlertEffect with WireEnum {
  noService('NO_SERVICE'),
  reducedService('REDUCED_SERVICE'),
  significantDelays('SIGNIFICANT_DELAYS'),
  detour('DETOUR'),
  additionalService('ADDITIONAL_SERVICE'),
  modifiedService('MODIFIED_SERVICE'),
  otherEffect('OTHER_EFFECT'),
  unknownEffect('UNKNOWN_EFFECT'),
  stopMoved('STOP_MOVED'),
  noEffect('NO_EFFECT'),
  accessibilityIssue('ACCESSIBILITY_ISSUE');

  const AlertEffect(this.wireName);

  @override
  final String wireName;

  static AlertEffect? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum AlertSeverityLevel with WireEnum {
  unknownSeverity('UNKNOWN_SEVERITY'),
  info('INFO'),
  warning('WARNING'),
  severe('SEVERE');

  const AlertSeverityLevel(this.wireName);

  @override
  final String wireName;

  static AlertSeverityLevel? fromWire(Object? raw) => enumFromWire(values, raw);
}

enum FareMediaType with WireEnum {
  none('NONE'),
  paperTicket('PAPER_TICKET'),
  transitCard('TRANSIT_CARD'),
  contactlessEmv('CONTACTLESS_EMV'),
  mobileApp('MOBILE_APP');

  const FareMediaType(this.wireName);

  @override
  final String wireName;

  static FareMediaType? fromWire(Object? raw) => enumFromWire(values, raw);
}

/// How a fare transfer combines the products of the legs it covers.
enum FareTransferRule with WireEnum {
  aAb('A_AB'),
  aAbB('A_AB_B'),
  ab('AB');

  const FareTransferRule(this.wireName);

  @override
  final String wireName;

  static FareTransferRule? fromWire(Object? raw) => enumFromWire(values, raw);
}
