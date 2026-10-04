import '../models/itinerary.dart';
import 'itinerary_leg_utils.dart';

/// Writes a leg for the background service, which runs in an isolate of its
/// own and can only be sent plain data.
///
/// Only what tracking and its notification use is written: where the leg
/// goes and through, when, and what to call it. It is not a leg's full JSON,
/// which the app never needs to write — an itinerary keeps the planner's
/// original — and a rebuilt leg is not meant to be shown anywhere else.
Map<String, dynamic> displayLegToJson(DisplayLegInfo entry) {
  final leg = entry.leg;
  return {
    'leg': {
      'mode': leg.mode,
      'from': _placeToJson(leg.from),
      'to': _placeToJson(leg.to),
      'intermediateStops': [
        for (final stop in leg.intermediateStops) _placeToJson(stop),
      ],
      'startTime': leg.startTime.toUtc().toIso8601String(),
      'endTime': leg.endTime.toUtc().toIso8601String(),
      'scheduledStartTime': leg.scheduledStartTime?.toUtc().toIso8601String(),
      'duration': leg.duration,
      'distance': leg.distance,
      'realTime': leg.realTime,
      'displayName': leg.displayName,
      'routeShortName': leg.routeShortName,
      'headsign': leg.headsign,
    },
    'originalIndex': entry.originalIndex,
    'type': entry.type.name,
  };
}

/// The inverse of [displayLegToJson].
DisplayLegInfo displayLegFromJson(Map<String, dynamic> json) {
  final leg = (json['leg'] as Map).cast<String, dynamic>();
  return DisplayLegInfo(
    leg: Leg(
      mode: leg['mode'] as String,
      from: _placeFromJson(leg['from']),
      to: _placeFromJson(leg['to']),
      intermediateStops: [
        for (final stop in leg['intermediateStops'] as List)
          _placeFromJson(stop),
      ],
      startTime: DateTime.parse(leg['startTime'] as String),
      endTime: DateTime.parse(leg['endTime'] as String),
      scheduledStartTime: switch (leg['scheduledStartTime']) {
        final String time => DateTime.parse(time),
        _ => null,
      },
      duration: leg['duration'] as int,
      distance: (leg['distance'] as num?)?.toDouble(),
      realTime: leg['realTime'] as bool,
      displayName: leg['displayName'] as String?,
      routeShortName: leg['routeShortName'] as String?,
      headsign: leg['headsign'] as String?,
    ),
    originalIndex: json['originalIndex'] as int,
    type: DisplayLegType.values.byName(json['type'] as String),
  );
}

Map<String, dynamic> _placeToJson(TransitPlace place) => {
  'name': place.name,
  'lat': place.lat,
  'lon': place.lon,
  'stopId': place.stopId,
};

TransitPlace _placeFromJson(Object? json) {
  final place = (json as Map).cast<String, dynamic>();
  return TransitPlace(
    name: place['name'] as String,
    lat: (place['lat'] as num).toDouble(),
    lon: (place['lon'] as num).toDouble(),
    stopId: place['stopId'] as String?,
  );
}
