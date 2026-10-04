import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/utils/geo_utils.dart';
import 'package:transportia/utils/polyline_utils.dart';

/// The real thing `/trip` answers with: the S7 end to end, Ahrensfelde to
/// Potsdam, whatever slice of it a journey happens to ride.
Leg _wholeTrip() {
  final json =
      jsonDecode(File('test/fixtures/transitous/trip.json').readAsStringSync())
          as Map<String, dynamic>;
  return Itinerary.fromJson(json).legs.single;
}

TransitPlace _named(String name) => TransitPlace(name: name, lat: 0, lon: 0);

void main() {
  group('cutting a whole trip down to the part travelled', () {
    test('the fixture really is the whole line', () {
      // If this ever stops being true the tests below prove nothing.
      final trip = _wholeTrip();
      expect(trip.fromName, 'S Ahrensfelde Bhf (Berlin)');
      expect(trip.toName, 'S Potsdam Hauptbahnhof');
      expect(trip.intermediateStops.length, 27);
    });

    test('only the stops between the two ends are kept', () {
      // An expanded leg listed every station on the line, most of which the
      // traveller never sees.
      final slice = _wholeTrip().sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      expect(slice.fromName, 'S Ostkreuz Bhf (Berlin)');
      expect(slice.toName, 'S Wannsee Bhf (Berlin)');
      expect(slice.intermediateStops.map((s) => s.name), [
        'S+U Warschauer Str. (Berlin)',
        'S Ostbahnhof (Berlin)',
        'S+U Jannowitzbrücke (Berlin)',
        'S+U Alexanderplatz Bhf (Berlin)',
        'S Hackescher Markt (Berlin)',
        'S+U Friedrichstr. Bhf (Berlin)',
        'S+U Berlin Hauptbahnhof',
        'S Bellevue (Berlin)',
        'S Tiergarten (Berlin)',
        'S+U Zoologischer Garten Bhf (Berlin)',
        'S Savignyplatz (Berlin)',
        'S Charlottenburg Bhf (Berlin)',
        'S Westkreuz (Berlin)',
        'S Grunewald (Berlin)',
        'S Nikolassee (Berlin)',
      ]);
      // Neither end is repeated inside.
      expect(
        slice.intermediateStops.map((s) => s.name),
        isNot(contains('S Ostkreuz Bhf (Berlin)')),
      );
    });

    test('the times become the ones at those two stops', () {
      // The visible half of this bug was the stop list; the other half was a
      // leg reporting the line's first departure as its own.
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      final ostkreuz = trip.intermediateStops.firstWhere(
        (s) => s.name == 'S Ostkreuz Bhf (Berlin)',
      );
      final wannsee = trip.intermediateStops.firstWhere(
        (s) => s.name == 'S Wannsee Bhf (Berlin)',
      );

      expect(slice.startTime, ostkreuz.departure);
      expect(slice.endTime, wannsee.arrival);
      expect(slice.startTime, isNot(trip.startTime));
      expect(
        slice.duration,
        wannsee.arrival!.difference(ostkreuz.departure!).inSeconds,
      );
    });

    test('what the service is stays what the service is', () {
      // Slicing changes where you get on and off, not which train it is.
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      expect(slice.tripId, trip.tripId);
      expect(slice.mode, trip.mode);
      expect(slice.routeShortName, trip.routeShortName);
      // And where the whole service runs is still reachable.
      expect(slice.tripFrom?.name, 'S Ahrensfelde Bhf (Berlin)');
      expect(slice.tripTo?.name, 'S Potsdam Hauptbahnhof');
    });

    test('riding to the end of the line keeps the end of the line', () {
      final slice = _wholeTrip().sliceBetween(
        _named('S Grunewald (Berlin)'),
        _named('S Potsdam Hauptbahnhof'),
      );

      expect(slice.toName, 'S Potsdam Hauptbahnhof');
      expect(slice.intermediateStops.map((s) => s.name), [
        'S Nikolassee (Berlin)',
        'S Wannsee Bhf (Berlin)',
        'S Griebnitzsee Bhf',
        'S Babelsberg',
      ]);
    });

    test('a stop that is not on the trip leaves it alone', () {
      // A wrong slice is worse than an unsliced one: the times would then
      // belong to somewhere the traveller never goes.
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('Flughafen BER'),
      );

      expect(slice.intermediateStops.length, trip.intermediateStops.length);
      expect(slice.startTime, trip.startTime);
    });

    test('the two ends the wrong way round leave it alone', () {
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(
        _named('S Wannsee Bhf (Berlin)'),
        _named('S Ostkreuz Bhf (Berlin)'),
      );

      expect(slice.intermediateStops.length, trip.intermediateStops.length);
    });

    test('a platform id still finds its station', () {
      // The itinerary may name a platform where the trip names the station,
      // or the other way round; both are the place you stand.
      final trip = _wholeTrip();
      final ostkreuz = trip.intermediateStops.firstWhere(
        (s) => s.name == 'S Ostkreuz Bhf (Berlin)',
      );
      expect(ostkreuz.stopId, isNotNull);

      final slice = trip.sliceBetween(
        TransitPlace(
          name: 'renamed by the geocoder',
          lat: 0,
          lon: 0,
          stopId: ostkreuz.stopId,
        ),
        _named('S Wannsee Bhf (Berlin)'),
      );

      expect(slice.fromName, 'S Ostkreuz Bhf (Berlin)');
    });
  });

  group('the route shape of a slice', () {
    // Without this a map draws the whole line for a ride of a few stops.
    test('is cut down to the stretch ridden', () {
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      final whole = decodePolyline(
        trip.legGeometry!.points,
        trip.legGeometry!.precision,
      );
      final cut = decodePolyline(
        slice.legGeometry!.points,
        slice.legGeometry!.precision,
      );

      expect(cut.length, lessThan(whole.length));
      expect(slice.legGeometry!.length, cut.length);
      expect(slice.legGeometry!.precision, trip.legGeometry!.precision);
    });

    test(
      'starts at the stop it starts from and ends at the one it ends at',
      () {
        final trip = _wholeTrip();
        final slice = trip.sliceBetween(
          _named('S Ostkreuz Bhf (Berlin)'),
          _named('S Wannsee Bhf (Berlin)'),
        );

        final cut = decodePolyline(
          slice.legGeometry!.points,
          slice.legGeometry!.precision,
        );
        double metresTo(LatLng point, TransitPlace place) =>
            coordinateDistanceInMeters(
              point.latitude,
              point.longitude,
              place.lat,
              place.lon,
            );

        // The line is drawn along the track, so the stop is not on it exactly.
        expect(metresTo(cut.first, slice.from), lessThan(150));
        expect(metresTo(cut.last, slice.to), lessThan(150));
      },
    );

    test('is the whole shape when the whole trip is ridden', () {
      final trip = _wholeTrip();
      final slice = trip.sliceBetween(trip.from, trip.to);

      expect(slice.legGeometry!.points, trip.legGeometry!.points);
    });

    test('is dropped, not kept whole, when the leg has none', () {
      final trip = _wholeTrip();
      final withoutShape = Leg(
        mode: trip.mode,
        from: trip.from,
        to: trip.to,
        startTime: trip.startTime,
        endTime: trip.endTime,
        duration: trip.duration,
        intermediateStops: trip.intermediateStops,
      );

      final slice = withoutShape.sliceBetween(
        _named('S Ostkreuz Bhf (Berlin)'),
        _named('S Wannsee Bhf (Berlin)'),
      );

      expect(slice.legGeometry, isNull);
    });
  });

  group('finding a stop on a leg', () {
    test('the sequence runs from origin to terminus', () {
      final trip = _wholeTrip();

      expect(trip.stopSequence, hasLength(29));
      expect(trip.stopSequence.first.name, trip.fromName);
      expect(trip.stopSequence.last.name, trip.toName);
    });

    test('gives where a stop is, by name or by id', () {
      final trip = _wholeTrip();

      expect(trip.indexOfStop(_named('S Ahrensfelde Bhf (Berlin)')), 0);
      expect(trip.indexOfStop(_named('S Potsdam Hauptbahnhof')), 28);
      final ostkreuz = trip.stopSequence.firstWhere(
        (s) => s.name == 'S Ostkreuz Bhf (Berlin)',
      );
      expect(
        trip.indexOfStop(
          TransitPlace(
            name: 'something else',
            lat: 0,
            lon: 0,
            stopId: ostkreuz.stopId,
          ),
        ),
        trip.stopSequence.indexOf(ostkreuz),
      );
    });

    test('is null for a stop the leg does not call at', () {
      expect(_wholeTrip().indexOfStop(_named('Flughafen BER')), isNull);
    });
  });
}
