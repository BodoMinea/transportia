import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/transitous/enums.dart';

void main() {
  test('regional trains and up are mainline, the deprecated alias too', () {
    for (final mode in [
      TransitMode.rail,
      TransitMode.highspeedRail,
      TransitMode.longDistance,
      TransitMode.nightRail,
      TransitMode.regionalRail,
      TransitMode.regionalFastRail,
    ]) {
      expect(mode.isRegionalOrLongerRail, isTrue, reason: mode.name);
      expect(mode.isTrain, isTrue, reason: mode.name);
    }
  });

  test('a suburban train is a train, but not mainline', () {
    expect(TransitMode.suburban.isTrain, isTrue);
    expect(TransitMode.suburban.isRegionalOrLongerRail, isFalse);
  });

  test('metro and tram run to platforms without being trains', () {
    for (final mode in [
      TransitMode.subway,
      TransitMode.metro,
      TransitMode.tram,
    ]) {
      expect(mode.runsToNumberedPlatforms, isTrue, reason: mode.name);
      expect(mode.isTrain, isFalse, reason: mode.name);
    }
  });

  test('buses, boats and walks have no platforms to miss', () {
    for (final mode in [
      TransitMode.bus,
      TransitMode.coach,
      TransitMode.ferry,
      TransitMode.walk,
    ]) {
      expect(mode.runsToNumberedPlatforms, isFalse, reason: mode.name);
    }
  });
}
