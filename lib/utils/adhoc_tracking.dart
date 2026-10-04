import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/itinerary.dart';
import '../models/stop_time.dart';
import '../screens/itinerary_map_screen.dart';
import '../services/itinerary_tracking_controller.dart';
import '../services/location_service.dart';
import '../services/trip_details_service.dart';
import '../widgets/destination_stop_picker.dart';
import '../widgets/validation_toast.dart';
import 'custom_page_route.dart';
import 'geo_utils.dart';
import 'haptics.dart';
import 'itinerary_leg_utils.dart';

/// How close the rider has to be to the stop they board at for the trip to
/// count as one they are on. The same "plausibly on it" distance the journey
/// map uses to offer tracking.
const double kAdHocProximityMetres = 250.0;

/// Starts following [stopTime] directly, as tapped in a departures list or a
/// stop's popup, rather than a searched journey. Needs the rider to be at the
/// stop they board at; asks where they are getting off, then follows a
/// one-leg journey covering just that stretch of the trip.
Future<void> startAdHocTracking(BuildContext context, StopTime stopTime) async {
  final hasPermission = await LocationService.ensurePermission();
  if (!context.mounted) return;
  if (!hasPermission) {
    showValidationToast(
      context,
      'Location permission is needed to track a trip.',
    );
    return;
  }

  final position = await LocationService.currentOrLastKnownLatLng();
  if (!context.mounted) return;
  if (position == null ||
      coordinateDistanceInMeters(
            position.latitude,
            position.longitude,
            stopTime.place.lat,
            stopTime.place.lon,
          ) >
          kAdHocProximityMetres) {
    showValidationToast(context, "You're too far from this stop to track it.");
    return;
  }

  Itinerary tripDetails;
  try {
    tripDetails = await TripDetailsService.fetchTripDetails(
      tripId: stopTime.tripId,
    );
  } catch (_) {
    if (!context.mounted) return;
    showValidationToast(context, 'Could not load this trip.');
    return;
  }
  if (!context.mounted || tripDetails.legs.isEmpty) return;

  // A trip fetched by id can come wrapped in walking legs; the ride is the
  // one that is not a walk.
  final fullLeg = tripDetails.legs.firstWhere(
    (leg) => leg.mode != 'WALK',
    orElse: () => tripDetails.legs.first,
  );
  final stops = fullLeg.stopSequence;
  final boardingIndex = boardingIndexOn(fullLeg, stopTime.place);
  if (boardingIndex == null || boardingIndex >= stops.length - 1) {
    showValidationToast(context, 'Could not find this stop on the trip.');
    return;
  }

  final alightingIndex = await showDestinationStopPicker(
    context,
    stops: stops,
    boardingIndex: boardingIndex,
  );
  if (alightingIndex == null || !context.mounted) return;

  final ridden = fullLeg.sliceBetween(
    stops[boardingIndex],
    stops[alightingIndex],
  );
  final wholeTrip = boardingIndex == 0 && alightingIndex == stops.length - 1;
  if (identical(ridden, fullLeg) && !wholeTrip) {
    // sliceBetween leaves a leg alone when it cannot find an end of it;
    // following the whole line would put the rider on stops they never use.
    showValidationToast(context, 'Could not follow that part of the trip.');
    return;
  }

  final itinerary = Itinerary(
    duration: ridden.duration,
    startTime: ridden.startTime,
    endTime: ridden.endTime,
    transfers: 0,
    legs: [ridden],
    isDirect: true,
  );

  unawaited(Haptics.mediumTick());
  await ItineraryTrackingController.start(
    legs: buildDisplayLegs(itinerary.legs),
    fingerprint: ItineraryTrackingController.fingerprintFor(itinerary),
    initialPos: position,
    startLegIndex: 0,
  );
  if (!context.mounted) return;

  await Navigator.of(
    context,
  ).push(CustomPageRoute(child: ItineraryMapScreen(itinerary: itinerary)));
}

/// Where [boarding] is on [leg]: by stop id or name when the leg calls there,
/// otherwise at the stop nearest to it, since the lists that feed this do not
/// always carry an id the trip agrees with. Null for a leg with no stops.
int? boardingIndexOn(Leg leg, TransitPlace boarding) {
  final exact = leg.indexOfStop(boarding);
  if (exact != null) return exact;

  int? nearestIndex;
  var nearestDistance = double.infinity;
  final stops = leg.stopSequence;
  for (var i = 0; i < stops.length; i++) {
    final distance = coordinateDistanceInMeters(
      stops[i].lat,
      stops[i].lon,
      boarding.lat,
      boarding.lon,
    );
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }
  return nearestIndex;
}
