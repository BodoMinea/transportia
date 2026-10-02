import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/models/my_location.dart';
import 'package:transportia/models/route_field_kind.dart';
import 'package:transportia/services/transitous_geocode_service.dart';

/// Picking "My Location" means two different things depending on which end of
/// the trip it is for, and getting that backwards is a silent failure: an
/// origin that was pinned to a stale coordinate, or a destination the search
/// rejects as empty.
void main() {
  test('an origin is left for the search to resolve', () {
    // An empty origin already means "from where I am", read when Search is
    // pressed — so the trip starts where you are then, not where you were
    // when you picked.
    expect(myLocationSelectionFor(RouteFieldKind.from, 52.52, 13.41), isNull);
  });

  test('a destination takes the position as it stands', () {
    // The planner rejects an empty destination outright, so this end has to
    // carry real coordinates.
    final selection = myLocationSelectionFor(RouteFieldKind.to, 52.52, 13.41);

    expect(selection, isNotNull);
    expect(selection!.lat, 52.52);
    expect(selection.lon, 13.41);
    expect(selection.name, myLocationName);
  });

  test('a resolved position is still recognisable as My Location', () {
    // Recognised by id rather than by name, so a stop that happens to be
    // called "My Location" is not mistaken for it.
    expect(myLocationAt(52.52, 13.41).id, myLocationSuggestion.id);
  });

  group('swapRouteEnds', () {
    const here = LatLng(52.52, 13.41);
    final alex = TransitousLocationSuggestion(
      id: 'alex',
      name: 'Alexanderplatz',
      lat: 52.521,
      lon: 13.413,
      type: 'STOP',
    );
    final alexEnd = RouteEnd('Alexanderplatz', alex);

    test('an implicit origin becomes a pinned My Location destination', () {
      final swapped = swapRouteEnds(
        from: RouteEnd.empty,
        to: alexEnd,
        originIsMyLocation: true,
        position: here,
      )!;

      expect(swapped.from.text, 'Alexanderplatz');
      expect(swapped.from.selection, alex);
      expect(swapped.to.text, myLocationName);
      expect(swapped.to.selection!.id, myLocationSuggestion.id);
      // LatLng re-normalises longitude, so not bit-for-bit.
      expect(swapped.to.selection!.lat, closeTo(52.52, 1e-9));
      expect(swapped.to.selection!.lon, closeTo(13.41, 1e-9));
    });

    test('is refused when My Location has no position to pin to', () {
      expect(
        swapRouteEnds(
          from: RouteEnd.empty,
          to: alexEnd,
          originIsMyLocation: true,
        ),
        isNull,
      );
    });

    test('swapping twice returns an empty origin and the place', () {
      final once = swapRouteEnds(
        from: RouteEnd.empty,
        to: alexEnd,
        originIsMyLocation: true,
        position: here,
      )!;
      final twice = swapRouteEnds(
        from: once.from,
        to: once.to,
        originIsMyLocation: true,
        position: here,
      )!;

      expect(twice.from.text, '');
      expect(twice.from.selection, isNull);
      expect(twice.to.text, 'Alexanderplatz');
      expect(twice.to.selection, alex);
    });

    test('a My Location destination goes back to an empty origin', () {
      final swapped = swapRouteEnds(
        from: alexEnd,
        to: RouteEnd(myLocationName, myLocationAt(52.52, 13.41)),
        originIsMyLocation: true,
        position: here,
      )!;

      expect(swapped.from.text, '');
      expect(swapped.from.selection, isNull);
      expect(swapped.to, alexEnd);
    });

    test('without permission the pinned My Location stays as an origin', () {
      final mine = RouteEnd(myLocationName, myLocationAt(52.52, 13.41));
      final swapped = swapRouteEnds(
        from: alexEnd,
        to: mine,
        originIsMyLocation: false,
      )!;

      expect(swapped.from, mine);
      expect(swapped.to, alexEnd);
    });

    test('two places simply trade', () {
      final other = RouteEnd(
        'Hauptbahnhof',
        TransitousLocationSuggestion(
          id: 'hbf',
          name: 'Hauptbahnhof',
          lat: 52.525,
          lon: 13.369,
          type: 'STOP',
        ),
      );
      final swapped = swapRouteEnds(
        from: alexEnd,
        to: other,
        originIsMyLocation: true,
        position: here,
      )!;

      expect(swapped.from, other);
      expect(swapped.to, alexEnd);
    });

    test('without permission an empty origin swaps as before', () {
      final swapped = swapRouteEnds(
        from: RouteEnd.empty,
        to: alexEnd,
        originIsMyLocation: false,
        position: here,
      )!;

      expect(swapped.from, alexEnd);
      expect(swapped.to.text, '');
      expect(swapped.to.selection, isNull);
    });

    test('with both ends empty nothing moves', () {
      final swapped = swapRouteEnds(
        from: RouteEnd.empty,
        to: RouteEnd.empty,
        originIsMyLocation: true,
        position: here,
      )!;

      expect(swapped.from, RouteEnd.empty);
      expect(swapped.to, RouteEnd.empty);
    });

    test('a place merely named My Location is an ordinary place', () {
      final lookalike = RouteEnd(
        myLocationName,
        TransitousLocationSuggestion(
          id: 'some-stop',
          name: myLocationName,
          lat: 1,
          lon: 2,
          type: 'STOP',
        ),
      );
      final swapped = swapRouteEnds(
        from: alexEnd,
        to: lookalike,
        originIsMyLocation: true,
        position: here,
      )!;

      expect(swapped.from, lookalike);
      expect(swapped.to, alexEnd);
    });
  });
}
