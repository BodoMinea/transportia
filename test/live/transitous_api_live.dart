// Drives every endpoint against the real api.transitous.org.
//
// Deliberately not named `*_test.dart`, so `flutter test` skips it: it needs
// the network and asserts on live timetable data. Run it explicitly after
// touching the API layer, or when the server is upgraded:
//
//     flutter test test/live/transitous_api_live.dart
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/api/endpoints/geocode_endpoint.dart';
import 'package:transportia/api/endpoints/map_endpoint.dart';
import 'package:transportia/api/endpoints/misc_endpoints.dart';
import 'package:transportia/api/endpoints/plan_endpoint.dart';
import 'package:transportia/api/endpoints/reach_endpoint.dart';
import 'package:transportia/api/endpoints/stoptimes_endpoint.dart';
import 'package:transportia/api/endpoints/trip_endpoint.dart';
import 'package:transportia/api/params/plan_params.dart';
import 'package:transportia/api/transitous_api_exception.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/models/transitous/itinerary_id.dart';

const alexanderplatz = 'de-DELFI_de:11000:900100003';

void main() {
  test('plan with the full option set', () async {
    final response = await PlanEndpoint.plan(
      PlanParams(
        fromPlace: '52.520000,13.405000',
        toPlace: '53.551100,9.993700',
        time: DateTime.now().toUtc().add(const Duration(hours: 2)),
        numItineraries: 2,
        maxTransfers: 4,
        additionalTransferTime: const Duration(minutes: 5),
        pedestrianSpeed: 1.2,
        cyclingSpeed: 4.2,
        elevationCosts: ElevationCosts.low,
        useRoutedTransfers: true,
        requireBikeTransport: false,
        noCompulsoryReservation: true,
        preTransitModes: const [TransitMode.walk],
        maxPreTransitTime: const Duration(minutes: 15),
        postTransitModes: const [TransitMode.walk],
        maxPostTransitTime: const Duration(minutes: 15),
        directModes: const [TransitMode.walk],
        maxDirectTime: const Duration(minutes: 30),
        transitModes: const [TransitMode.transit],
        withFares: true,
        detailedLegs: true,
        numLegAlternatives: 1,
        realtimeMode: RealtimeMode.realtime,
      ),
    );
    expect(response.itineraries, isNotEmpty);
    // ignore: avoid_print
    print('plan: ${response.itineraries.length} itineraries');
  });

  test('plan with a via stop', () async {
    final response = await PlanEndpoint.plan(
      PlanParams(
        fromPlace: '52.520000,13.405000',
        toPlace: '53.551100,9.993700',
        via: const [
          ViaStop(
            stopId: 'de-DELFI_de:11000:900003201',
            minimumStay: Duration(minutes: 5),
          ),
        ],
        numItineraries: 1,
        time: DateTime.now().toUtc().add(const Duration(hours: 2)),
      ),
    );
    expect(response.itineraries, isNotEmpty);
  });

  test('trip and refresh-itinerary in both forms', () async {
    final plan = await PlanEndpoint.plan(
      PlanParams(
        fromPlace: '52.520000,13.405000',
        toPlace: '53.551100,9.993700',
        numItineraries: 1,
        time: DateTime.now().toUtc().add(const Duration(hours: 2)),
      ),
    );
    final itinerary = plan.itineraries.first;

    final tripId = itinerary.legs
        .map((l) => l.tripId)
        .firstWhere((id) => id != null && id.isNotEmpty)!;
    final trip = await TripEndpoint.trip(tripId: tripId);
    expect(trip.legs, isNotEmpty);

    // GET form, opaque id.
    final refreshed = await TripEndpoint.refreshItinerary(
      itineraryId: itinerary.id!,
    );
    expect(refreshed.legs, isNotEmpty);
    // ignore: avoid_print
    print('refresh GET: ${refreshed.legs.length} legs');

    // POST form, structured id derived from the legs.
    final byId = await TripEndpoint.refreshItineraryById(
      id: ItineraryId.fromItinerary(itinerary),
    );
    expect(byId.legs, isNotEmpty);
    // ignore: avoid_print
    print('refresh POST: ${byId.legs.length} legs');
  });

  test('stoptimes and stop', () async {
    final stopTimes = await StopTimesEndpoint.stopTimes(
      stopId: alexanderplatz,
      n: 5,
      withAlerts: true,
      fetchStops: true,
      radius: 30,
    );
    expect(stopTimes.stopTimes, isNotEmpty);

    final stop = await StopTimesEndpoint.stop(stopId: alexanderplatz);
    expect(stop.place.name, isNotEmpty);
    expect(stop.routes, isNotEmpty);
    // ignore: avoid_print
    print('stop: ${stop.place.name}, ${stop.routes.length} routes');
  });

  test('geocode and reverse-geocode', () async {
    final matches = await GeocodeEndpoint.geocode(
      text: 'Alexanderplatz',
      placeLat: 52.52,
      placeLon: 13.405,
      placeBias: 1.5,
    );
    expect(matches, isNotEmpty);

    final reverse = await GeocodeEndpoint.reverseGeocode(
      lat: 52.5215,
      lon: 13.4112,
    );
    expect(reverse, isNotEmpty);
    // ignore: avoid_print
    print('geocode: ${matches.first.name} / ${reverse.first.name}');
  });

  test('map endpoints', () async {
    final now = DateTime.now().toUtc();
    final trips = await MapEndpoint.trips(
      zoom: 14,
      minLat: 52.51,
      minLon: 13.39,
      maxLat: 52.53,
      maxLon: 13.42,
      startTime: now,
      endTime: now.add(const Duration(minutes: 10)),
    );
    expect(trips, isNotEmpty);

    final stops = await MapEndpoint.stops(
      minLat: 52.51,
      minLon: 13.39,
      maxLat: 52.53,
      maxLon: 13.42,
    );
    expect(stops, isNotEmpty);

    final initial = await MapEndpoint.initial();
    expect(initial.serverConfig.motisVersion, isNotEmpty);

    final levels = await MapEndpoint.levels(
      minLat: 52.51,
      minLon: 13.39,
      maxLat: 52.53,
      maxLon: 13.42,
    );
    expect(levels, isA<List<double>>());

    final routes = await MapEndpoint.routes(
      zoom: 12,
      minLat: 52.515,
      minLon: 13.400,
      maxLat: 52.525,
      maxLon: 13.415,
    );
    expect(routes.routes, isNotEmpty);

    final details = await MapEndpoint.routeDetails(
      routeIndex: routes.routes.first.routeIndex,
    );
    expect(details.routes, isNotEmpty);
    // ignore: avoid_print
    print(
      'map: ${trips.length} trips, ${stops.length} stops, '
      '${levels.length} levels, ${routes.routes.length} routes, '
      'motis ${initial.serverConfig.motisVersion}',
    );
  });

  test('reachability endpoints', () async {
    final many = await ReachEndpoint.oneToMany(
      oneLat: 52.52,
      oneLon: 13.40,
      many: const [(lat: 52.51, lon: 13.39), (lat: 52.53, lon: 13.41)],
      mode: TransitMode.walk,
      max: const Duration(minutes: 30),
      maxMatchingDistance: 250,
      arriveBy: false,
      withDistance: true,
    );
    expect(many, hasLength(2));
    expect(many.first.isReachable, isTrue);

    final all = await ReachEndpoint.oneToAll(
      oneLat: 52.52,
      oneLon: 13.40,
      maxTravelTime: const Duration(minutes: 15),
      time: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
    expect(all.all, isNotEmpty);

    final intermodal = await ReachEndpoint.oneToManyIntermodal(
      oneLat: 52.52,
      oneLon: 13.40,
      many: const [(lat: 52.51, lon: 13.39)],
      maxTravelTime: const Duration(minutes: 30),
      time: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
    expect(intermodal.streetDurations, isNotEmpty);
    // ignore: avoid_print
    print(
      'reach: ${many.length} one-to-many, ${all.all.length} reachable, '
      '${intermodal.streetDurations.length} intermodal',
    );
  });

  test('rentals returns the requested region', () async {
    final rentals = await RentalsEndpoint.rentals(
      minLat: 52.51,
      minLon: 13.39,
      maxLat: 52.52,
      maxLon: 13.40,
      withProviders: true,
      withStations: true,
      withVehicles: true,
      withZones: true,
    );
    expect(rentals.providerGroups, isNotEmpty);
    // The semicolon coordinate form silently answers with providers from
    // elsewhere in the country, so check we actually got Berlin operators.
    expect(
      rentals.providerGroups.map((g) => g.id).join(','),
      contains('Berlin'),
    );
    // ignore: avoid_print
    print('rentals: ${rentals.providerGroups.map((g) => g.id).take(3)}');
  });

  test('health', () async {
    final health = await HealthEndpoint.health();
    expect(health.realtime, isTrue);
  });

  test('debug transfers', () async {
    final debug = await DebugEndpoint.transfers(stopId: alexanderplatz);
    expect(debug.place.name, isNotEmpty);
    expect(debug.transfers, isNotEmpty);
    // ignore: avoid_print
    print(
      'transfers: ${debug.transfers.length} out of ${debug.place.name}, '
      'wheelchair=${debug.hasWheelchairTransfers}',
    );
  });

  test('an unknown stop id is a 404', () async {
    await expectLater(
      DebugEndpoint.transfers(stopId: 'not-a-stop'),
      throwsA(
        isA<TransitousApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });
}
