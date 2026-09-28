import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/place_caption.dart';

void main() {
  group('placeCaption', () {
    test('distance, district and city', () {
      expect(
        placeCaption(
          name: 'REWE',
          district: 'Prenzlauer Berg',
          city: 'Berlin',
          region: 'Berlin',
          country: 'DE',
          homeCountry: 'DE',
          metres: 1290,
        ),
        '1.3 km · Prenzlauer Berg, Berlin',
      );
    });

    test('the region stands in for a missing district', () {
      expect(
        placeCaption(
          name: 'Paris',
          city: 'Paris',
          region: 'Texas',
          country: 'US',
          homeCountry: 'DE',
          metres: 8231000,
        ),
        '8231 km · Texas, US',
      );
    });

    test('a district leaves the region out', () {
      expect(
        placeCaption(
          name: 'Marienplatz',
          district: 'Altstadt-Lehel',
          city: 'München',
          region: 'Bayern',
        ),
        'Altstadt-Lehel, München',
      );
    });

    test('an area repeating the name is dropped, whatever its case', () {
      expect(
        placeCaption(name: 'Leipzig', city: 'LEIPZIG', region: 'Sachsen'),
        'Sachsen',
      );
    });

    test('an area repeating an earlier one is dropped', () {
      expect(
        placeCaption(name: 'REWE', district: 'Mitte', city: 'Mitte'),
        'Mitte',
      );
    });

    test('the home country is not spelt out, in any case', () {
      expect(
        placeCaption(
          name: 'X',
          city: 'Berlin',
          country: 'de',
          homeCountry: 'DE',
        ),
        'Berlin',
      );
    });

    test('with no home country known, every country shows', () {
      expect(
        placeCaption(name: 'X', city: 'Berlin', country: 'DE'),
        'Berlin, DE',
      );
    });

    test('no distance without a position', () {
      expect(placeCaption(name: 'X', city: 'Berlin'), 'Berlin');
    });

    test('distance alone when no area says anything', () {
      expect(
        placeCaption(name: 'Berlin', city: 'Berlin', metres: 300),
        '300 m',
      );
    });

    test('empty and blank areas are nothing', () {
      expect(
        placeCaption(name: 'X', district: ' ', city: '', region: 'Bayern'),
        'Bayern',
      );
      expect(placeCaption(name: 'X'), '');
    });
  });

  group('formatPlaceDistance', () {
    test('metres in tens under a kilometre', () {
      expect(formatPlaceDistance(0), '0 m');
      expect(formatPlaceDistance(347), '350 m');
      expect(formatPlaceDistance(994), '990 m');
    });

    test('rounding up to a kilometre reads as kilometres', () {
      expect(formatPlaceDistance(995), '1.0 km');
      expect(formatPlaceDistance(1000), '1.0 km');
    });

    test('one decimal under ten kilometres', () {
      expect(formatPlaceDistance(1250), '1.3 km');
      expect(formatPlaceDistance(9940), '9.9 km');
    });

    test('rounding up to ten reads as whole kilometres', () {
      expect(formatPlaceDistance(9960), '10 km');
      expect(formatPlaceDistance(10000), '10 km');
    });

    test('whole kilometres far away', () {
      expect(formatPlaceDistance(877600), '878 km');
    });
  });

  group('categoryLabel', () {
    test('drops the number MOTIS appends', () {
      expect(categoryLabel('supermarket_14'), 'Supermarket');
      expect(categoryLabel('fast_food_16'), 'Fast food');
    });

    test('a category without a number reads the same', () {
      expect(categoryLabel('square'), 'Square');
      expect(categoryLabel('parking_entrance_14'), 'Parking entrance');
    });

    test('a settlement, none and nothing are no label', () {
      expect(categoryLabel('place_6'), isNull);
      expect(categoryLabel('place_capital_8'), isNull);
      expect(categoryLabel('none'), isNull);
      expect(categoryLabel(''), isNull);
      expect(categoryLabel('_14'), isNull);
      expect(categoryLabel(null), isNull);
    });
  });
}
