import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/utils/favorite_icons.dart';
import 'package:transportia/utils/leg_helper.dart';
import 'package:transportia/utils/place_icons.dart';

List<TransitMode> _modes(List<String> wire) => [
  for (final name in wire) TransitMode.fromWire(name)!,
];

void main() {
  group('the mode a stop is known by', () {
    test('a railway station with buses is a railway station', () {
      // S+U Alexanderplatz as the geocoder answers it.
      expect(
        headlineMode(_modes(['REGIONAL_RAIL', 'SUBURBAN', 'SUBWAY', 'BUS'])),
        TransitMode.rail,
      );
    });

    test('an S-Bahn station is a railway station, not a tram stop', () {
      // The suburban leg borrows the tram glyph; a station should not.
      expect(headlineMode(_modes(['SUBURBAN'])), TransitMode.rail);
      expect(stopIcon(_modes(['SUBURBAN'])), LucideIcons.trainFront);
    });

    test('each rank beats the ones below it', () {
      expect(
        headlineMode(_modes(['BUS', 'AIRPLANE', 'RAIL'])),
        TransitMode.airplane,
      );
      expect(
        headlineMode(_modes(['BUS', 'TRAM', 'SUBWAY'])),
        TransitMode.subway,
      );
      expect(headlineMode(_modes(['BUS', 'TRAM'])), TransitMode.tram);
      expect(headlineMode(_modes(['BUS', 'FERRY'])), TransitMode.ferry);
      expect(
        headlineMode(_modes(['BUS', 'FUNICULAR'])),
        TransitMode.aerialLift,
      );
      expect(headlineMode(_modes(['COACH', 'BUS'])), TransitMode.bus);
      expect(headlineMode(_modes(['COACH'])), TransitMode.coach);
    });

    test('deprecated aliases count as what they stand for', () {
      expect(headlineMode(_modes(['METRO'])), TransitMode.subway);
      expect(headlineMode(_modes(['REGIONAL_FAST_RAIL'])), TransitMode.rail);
      expect(headlineMode(_modes(['CABLE_CAR'])), TransitMode.aerialLift);
      expect(headlineMode(_modes(['AREAL_LIFT'])), TransitMode.aerialLift);
    });

    test('nothing known, or nothing drawable, is no mode', () {
      expect(headlineMode(const []), isNull);
      expect(headlineMode(_modes(['ODM', 'FLEX', 'OTHER'])), isNull);
      expect(stopIcon(const []), kUnknownStopIcon);
    });
  });

  test('a stop is drawn with the glyph of its leg', () {
    // A station and a trip through it should not disagree about what a tram
    // looks like.
    for (final mode in [
      TransitMode.airplane,
      TransitMode.subway,
      TransitMode.tram,
      TransitMode.ferry,
      TransitMode.aerialLift,
      TransitMode.bus,
      TransitMode.coach,
    ]) {
      expect(stopIcon([mode]), getLegIcon(mode.wireName), reason: '$mode');
    }
  });

  group('a place', () {
    test('that is a stop is drawn by what serves it', () {
      expect(placeIcon('STOP', modes: _modes(['TRAM'])), LucideIcons.tramFront);
      expect(placeIcon('stop'), kUnknownStopIcon);
    });

    test('that is not a stop is drawn by its type', () {
      expect(placeIcon('ADDRESS'), LucideIcons.locateFixed);
      expect(placeIcon('PLACE'), LucideIcons.mapPin);
      // Modes do not turn an address into a station.
      expect(
        placeIcon('ADDRESS', modes: _modes(['RAIL'])),
        LucideIcons.locateFixed,
      );
    });
  });

  test('a stop is kept with the icon the lists drew it with', () {
    // Hearting a recent moves it up to Favourites; it should not change face
    // on the way.
    for (final modes in [
      <TransitMode>[],
      _modes(['REGIONAL_RAIL', 'BUS']),
      _modes(['SUBWAY']),
      _modes(['TRAM']),
      _modes(['FERRY']),
      _modes(['FUNICULAR']),
      _modes(['BUS']),
      _modes(['COACH']),
      _modes(['AIRPLANE']),
      _modes(['FLEX']),
    ]) {
      expect(
        iconForFavorite(favoriteIconNameForStop(modes)),
        stopIcon(modes),
        reason: '$modes',
      );
    }
  });
}
