import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/api/transitous_client.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

const _berlin = LatLng(52.52, 13.405);

String _fixture(String name) =>
    File('test/fixtures/transitous/$name').readAsStringSync();

/// Serves [body] to every request and records what was asked.
List<Uri> _serve(String body) {
  final requests = <Uri>[];
  TransitousClient.instance = TransitousClient(
    httpClient: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  return requests;
}

Map<String, dynamic> _match({
  required String name,
  required double lat,
  required double lon,
  String type = 'PLACE',
  String id = '',
}) => {
  'type': type,
  'name': name,
  'id': id,
  'lat': lat,
  'lon': lon,
  'score': 0,
  'areas': const [],
  'tokens': const [],
};

void main() {
  tearDown(() => TransitousClient.instance = TransitousClient());

  group('fetchSuggestions', () {
    test('asks with the measured bias and a page of twenty', () async {
      final requests = _serve('[]');

      await TransitousGeocodeService.fetchSuggestions(
        text: 'Rewe',
        placeBias: _berlin,
      );

      final query = requests.single.queryParameters;
      expect(query['placeBias'], '1.5');
      expect(query['numResults'], '20');
      expect(query['place'], '52.520000,13.405000');
    });

    test('sends no bias without a position', () async {
      final requests = _serve('[]');

      await TransitousGeocodeService.fetchSuggestions(text: 'Rewe');

      final query = requests.single.queryParameters;
      expect(query.containsKey('place'), isFalse);
      expect(query.containsKey('placeBias'), isFalse);
    });

    test('asks for more when asked to', () async {
      final requests = _serve('[]');

      await TransitousGeocodeService.fetchSuggestions(
        text: 'Rewe',
        numResults: 40,
      );

      expect(requests.single.queryParameters['numResults'], '40');
    });

    test('keeps every branch of a chain', () async {
      // Twenty REWEs across Berlin; the old ~10 km bucket kept four.
      _serve(_fixture('geocode_rewe.json'));

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Rewe',
        placeBias: _berlin,
      );

      expect(results, hasLength(20));
    });

    test('keeps the server order, places before stops included', () async {
      // Paris the city, then Paris-Est: MOTIS ranks the city first, and the
      // app no longer hoists stops over it.
      _serve(_fixture('geocode_paris.json'));
      final raw = (jsonDecode(_fixture('geocode_paris.json')) as List)
          .map((m) => (m as Map)['name'])
          .toList();

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Paris',
        placeBias: _berlin,
      );

      expect(results.first.type, 'PLACE');
      expect(results[1].name, 'Paris-Est');
      expect(results[1].type, 'STOP');
      expect(results.map((r) => r.name).toList(), raw.take(results.length));
    });

    test('merges the same name within 150 m, whatever its case', () async {
      // 0.001° of latitude is about 111 m.
      _serve(
        jsonEncode([
          _match(name: 'Hermannplatz', lat: 52.4870, lon: 13.4245),
          _match(name: 'HERMANNPLATZ', lat: 52.4880, lon: 13.4245),
        ]),
      );

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Hermannplatz',
      );

      expect(results, hasLength(1));
      expect(results.single.name, 'Hermannplatz');
    });

    test('keeps the same name 160 m apart', () async {
      _serve(
        jsonEncode([
          _match(name: 'REWE', lat: 52.5300, lon: 13.4100),
          _match(name: 'REWE', lat: 52.5300, lon: 13.4124),
        ]),
      );

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Rewe',
      );

      expect(results, hasLength(2));
    });

    test('keeps different names at the same spot', () async {
      _serve(
        jsonEncode([
          _match(name: 'Alexanderplatz', lat: 52.5219, lon: 13.4132),
          _match(
            name: 'S+U Alexanderplatz',
            lat: 52.5219,
            lon: 13.4132,
            type: 'STOP',
          ),
        ]),
      );

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Alexanderplatz',
      );

      expect(results, hasLength(2));
    });

    test('asks nothing under three characters', () async {
      final requests = _serve('[]');

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: ' Re ',
      );

      expect(results, isEmpty);
      expect(requests, isEmpty);
    });

    test('an empty answer is an empty list', () async {
      _serve('[]');

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Xyzzy',
      );

      expect(results, isEmpty);
    });

    test('skips a result without a name', () async {
      _serve(
        jsonEncode([
          _match(name: '', lat: 52.5, lon: 13.4),
          _match(name: 'Ostkreuz', lat: 52.503, lon: 13.469),
        ]),
      );

      final results = await TransitousGeocodeService.fetchSuggestions(
        text: 'Ostkreuz',
      );

      expect(results.map((r) => r.name), ['Ostkreuz']);
    });
  });

  group('isSamePlaceAs', () {
    TransitousLocationSuggestion at(String name, double lat) =>
        TransitousLocationSuggestion(
          id: name,
          name: name,
          lat: lat,
          lon: 13.4,
          type: 'PLACE',
        );

    test('149 m apart is the same place, 151 m is not', () {
      // One degree of latitude is 111 195 m on the sphere the helper uses.
      const metresPerDegree = 111195.0;
      final a = at('Lidl', 52.5);
      expect(a.isSamePlaceAs(at('Lidl', 52.5 + 149 / metresPerDegree)), isTrue);
      expect(
        a.isSamePlaceAs(at('Lidl', 52.5 + 151 / metresPerDegree)),
        isFalse,
      );
    });

    test('a place is itself', () {
      final a = at('Lidl', 52.5);
      expect(a.isSamePlaceAs(a), isTrue);
    });
  });
}
