import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/place_details.dart';

PlaceDetails _fixture(String name) => PlaceDetails.fromNominatim(
  ((jsonDecode(File('test/fixtures/nominatim/$name').readAsStringSync())
              as List)
          .single
      as Map<String, dynamic>),
);

void main() {
  group('OsmRef.parse', () {
    test('reads the ids MOTIS gives places', () {
      expect(OsmRef.parse('node/[578429141]'), const OsmRef('N', 578429141));
      expect(OsmRef.parse('way/[60541581]'), const OsmRef('W', 60541581));
      expect(OsmRef.parse('relation/[62422]'), const OsmRef('R', 62422));
    });

    test('names the element as Nominatim looks it up', () {
      expect(OsmRef.parse('node/[578429141]')!.lookupId, 'N578429141');
    });

    test('a stop, an address or nothing is not an OSM element', () {
      expect(OsmRef.parse('de-DELFI_de:11000:900100003'), isNull);
      expect(OsmRef.parse(''), isNull);
      expect(OsmRef.parse('node/578429141'), isNull);
      expect(OsmRef.parse('node/[]'), isNull);
      expect(OsmRef.parse('area/[1]'), isNull);
    });
  });

  group('PlaceDetails.fromNominatim', () {
    test('a shop with its hours, the plain phone key before contact:', () {
      final rewe = _fixture('lookup_rewe.json');

      expect(rewe.street, 'Schönhauser Allee 10-11');
      expect(rewe.locality, '10119 Berlin');
      expect(rewe.openingHours, 'Mo-Sa 07:00-23:30');
      expect(rewe.phone, '+49 30 44342306');
      expect(rewe.website, startsWith('https://www.rewe.de/'));
      expect(rewe.wheelchair, 'yes');
      expect(rewe.level, '0');
      expect(rewe.isEmpty, isFalse);
    });

    test('contact: keys when that is all there is', () {
      final mcd = _fixture('lookup_mcdonalds.json');

      expect(mcd.street, 'Grunerstraße 20');
      expect(mcd.phone, '+49 30 24085828');
      expect(mcd.website, 'http://www.mcdonalds.de');
      expect(mcd.openingHours, isNull);
      expect(mcd.level, '2');
    });

    test('a building mapped as a way', () {
      final kadewe = _fixture('lookup_kadewe.json');

      expect(kadewe.street, 'Tauentzienstraße 21-24');
      expect(kadewe.locality, '10789 Berlin');
      expect(kadewe.openingHours, startsWith('Mo-Th 10:00-20:00'));
    });

    test('nothing known is empty', () {
      final none = PlaceDetails.fromNominatim(const {});
      expect(none.isEmpty, isTrue);
      expect(none.street, isNull);
    });

    test('a house number without a road is no street', () {
      final details = PlaceDetails.fromNominatim(const {
        'address': {'house_number': '7', 'city': 'Berlin'},
      });
      expect(details.street, isNull);
      expect(details.locality, 'Berlin');
    });

    test('blank values count as missing', () {
      final details = PlaceDetails.fromNominatim(const {
        'extratags': {'phone': ' ', 'contact:phone': '+49 1'},
      });
      expect(details.phone, '+49 1');
    });
  });
}
