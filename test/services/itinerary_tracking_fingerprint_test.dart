import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/services/itinerary_tracking_controller.dart';

import '../support/plan_fixtures.dart';

Itinerary _journey({
  DateTime? departure,
  String tripId = 'trip-re7',
  String fromStop = 'S+U Berlin Hauptbahnhof',
}) => Itinerary.fromJson(
  planItineraryJson(
    departure: departure ?? DateTime.utc(2026, 9, 28, 8),
    tripId: tripId,
    fromStop: fromStop,
  ),
);

void main() {
  group('the fingerprint of a journey', () {
    test('is the same for the same journey', () {
      expect(
        ItineraryTrackingController.fingerprintFor(_journey()),
        ItineraryTrackingController.fingerprintFor(_journey()),
      );
    });

    test('survives a real-time refresh moving every time', () {
      // The detail screen refreshes under the map: the one that stops
      // tracking when it closes must still recognise what the other started.
      final planned = _journey();
      final delayed = planned.withLegs([
        for (final leg in planned.legs)
          Leg(
            mode: leg.mode,
            from: leg.from,
            to: leg.to,
            startTime: leg.startTime.add(const Duration(minutes: 12)),
            endTime: leg.endTime.add(const Duration(minutes: 12)),
            duration: leg.duration,
            tripId: leg.tripId,
          ),
      ]);
      expect(delayed.startTime, isNot(planned.startTime));

      expect(
        ItineraryTrackingController.fingerprintFor(delayed),
        ItineraryTrackingController.fingerprintFor(planned),
      );
    });

    test('differs for another departure of the same line', () {
      expect(
        ItineraryTrackingController.fingerprintFor(_journey()),
        isNot(
          ItineraryTrackingController.fingerprintFor(
            _journey(departure: DateTime.utc(2026, 9, 28, 9)),
          ),
        ),
      );
    });

    test('differs for another trip', () {
      expect(
        ItineraryTrackingController.fingerprintFor(_journey()),
        isNot(
          ItineraryTrackingController.fingerprintFor(
            _journey(tripId: 'trip-other'),
          ),
        ),
      );
    });

    test('is made for a journey built in code, which has no snapshot', () {
      final built = Itinerary(
        duration: 600,
        startTime: DateTime.utc(2026, 9, 28, 8),
        endTime: DateTime.utc(2026, 9, 28, 8, 10),
        transfers: 0,
        legs: [
          Leg(
            mode: 'BUS',
            from: const TransitPlace(name: 'A', lat: 1, lon: 2),
            to: const TransitPlace(name: 'B', lat: 3, lon: 4),
            startTime: DateTime.utc(2026, 9, 28, 8),
            endTime: DateTime.utc(2026, 9, 28, 8, 10),
            duration: 600,
            tripId: 'ad-hoc',
          ),
        ],
      );

      expect(
        ItineraryTrackingController.fingerprintFor(built),
        contains('ad-hoc'),
      );
    });

    test('does not fail for a journey with no legs', () {
      final empty = Itinerary(
        duration: 0,
        startTime: DateTime.utc(2026, 9, 28, 8),
        endTime: DateTime.utc(2026, 9, 28, 8),
        transfers: 0,
        legs: const [],
      );

      expect(
        () => ItineraryTrackingController.fingerprintFor(empty),
        returnsNormally,
      );
    });
  });
}
