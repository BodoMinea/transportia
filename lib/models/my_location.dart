import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/transitous_geocode_service.dart';
import 'route_field_kind.dart';

/// What the app calls the rider's current position.
///
/// The origin field leaves itself empty for this and resolves the position at
/// search time, so the trip is planned from where you are when you press
/// Search rather than where you were when you picked.
const String myLocationName = 'My Location';

/// The answer the picker returns for it — recognised by id, so a place that
/// happens to share the name is not mistaken for it.
final TransitousLocationSuggestion myLocationSuggestion =
    TransitousLocationSuggestion(
      id: 'my-location',
      name: myLocationName,
      lat: 0,
      lon: 0,
      type: 'PLACE',
    );

/// The rider's position as a pickable place, once it is actually known.
///
/// [myLocationSuggestion] is the token the picker returns; it carries no
/// coordinates because the picker has none. This is what the caller turns it
/// into once it has a fix, keeping the same id so a later reader can still
/// tell it from a geocoded place that happens to be nearby.
TransitousLocationSuggestion myLocationAt(double lat, double lon) =>
    TransitousLocationSuggestion(
      id: myLocationSuggestion.id,
      name: myLocationName,
      lat: lat,
      lon: lon,
      type: 'PLACE',
    );

/// What picking My Location means for a field.
///
/// The origin takes null: an empty origin already means "from where I am" and
/// is resolved when Search is pressed, so the trip starts where you are then
/// rather than where you were when you picked. The destination cannot do that
/// — the search rejects an empty destination — so it takes the fix as it
/// stands.
TransitousLocationSuggestion? myLocationSelectionFor(
  RouteFieldKind field,
  double lat,
  double lon,
) => field == RouteFieldKind.from ? null : myLocationAt(lat, lon);

/// One end of the route as the card holds it: what the field says, and the
/// place behind it when one was picked.
@immutable
class RouteEnd {
  const RouteEnd(this.text, this.selection);

  static const RouteEnd empty = RouteEnd('', null);

  final String text;
  final TransitousLocationSuggestion? selection;
}

/// Swaps origin and destination, carrying My Location across as itself.
///
/// An empty origin means My Location only when [originIsMyLocation] (the
/// rider has granted location); a destination means it when its selection
/// has My Location's id, never by its name. Each lands in the other field the
/// way that field takes it — see [myLocationSelectionFor].
///
/// Null when My Location has to become the destination and there is no
/// [position] to pin it to.
({RouteEnd from, RouteEnd to})? swapRouteEnds({
  required RouteEnd from,
  required RouteEnd to,
  required bool originIsMyLocation,
  LatLng? position,
}) {
  if (from.text.isEmpty && to.text.isEmpty) return (from: from, to: to);

  final fromIsMine = originIsMyLocation && from.text.isEmpty;
  final toIsMine = to.selection?.id == myLocationSuggestion.id;

  if (fromIsMine && toIsMine) return (from: from, to: to);

  if (fromIsMine) {
    if (position == null) return null;
    final here = myLocationAt(position.latitude, position.longitude);
    return (from: to, to: RouteEnd(myLocationName, here));
  }

  // Back to an empty origin, resolved when Search is pressed. Without
  // permission an empty origin means nothing, so the pinned fix stays.
  if (toIsMine && originIsMyLocation) return (from: RouteEnd.empty, to: from);

  return (from: to, to: from);
}
