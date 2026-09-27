# Code nothing calls

Declarations in `lib/` with no reference anywhere in `lib/` or `test/`. Each
entry says what it is and whether it is worth keeping.

Nothing here has been deleted. Some of it is a public API waiting for its
caller and some is genuinely finished with, and the two look identical from a
reference count — the judgement column is the point of the file.

`flutter analyze` already reports unused *private* members, and reports none;
everything below is public, which is why it goes unflagged.

Last swept: 2026-08-12, against `e60c97e`.

---

## Likely to be wanted again — keep

### `RoutingService.findRoutes` — `lib/services/routing_service.dart:13`

The unpaginated form of a search: calls `findRoutesPaginated` and hands back
just the itineraries. Every current caller wants the cursors, so nobody uses
it.

**Judgement:** keep. It is three lines over the method beside it, and any
caller that wants one page of results — a deep link, a widget, a test —
reaches for exactly this shape. Deleting it saves nothing and the next person
writes it again.

### `TransitPlace.effectiveArrival` / `effectiveDeparture` — `lib/models/transitous/place.dart:97,100`

"Real-time if we have it, scheduled otherwise." Still zero callers. Two sites
write the same expression out by hand — `stop_selection_modal.dart:274,277`,
which is `effectiveArrival` and `effectiveDeparture` exactly.

A third site is the interesting one: `stop_departures_sheet.dart:245` reads
`place.scheduledDeparture ?? place.departure`, the *reverse* preference. That
is either a deliberate "show the timetable, not the estimate" on a departure
board, or a slip — and nothing in the file says which.

The earlier note here also listed `stop.departure ?? stop.arrival` as a copy
of this pattern. It is not: that picks *which event* matters at a stop, not
real-time versus scheduled for one event. It now has its own name,
`timeAtStop`.

**Judgement:** keep, and adopt at the two modal sites. Settle the departures
sheet first, because adopting there would change what a rider sees.

### `TransitPlace.arrivalDelay` / `departureDelay` — `lib/models/transitous/place.dart:115,121`

Real-time minus scheduled, as a `Duration`.

**Judgement:** delete, rather than adopt. `computeDelay`
(`lib/utils/time_utils.dart:23`, 12 callers) answers the same question and
returns null below a one-minute threshold — the whole app therefore treats a
40-second delay as on time. These two do not, so adopting them anywhere would
quietly introduce a second definition of "late". Two getters that disagree
with the adopted helper are worse than none.

### `TicketUrls.isEmpty` — `lib/models/transitous/leg_details.dart:32`

`web == null && android == null && ios == null`.

**Judgement:** delete, together with the field it guards, unless ticket links
are planned. `Leg.ticketUrls` is parsed and carried through `copyWith`, but no
widget anywhere reads it — so this is a null-check on data that never reaches
a screen. Either wire the links into the fare card, or drop both.

### `Alert.isInEffectAt` — `lib/models/transitous/alert.dart:59`

Whether an alert's impact period covers a given moment.

**Judgement:** keep. Alerts are currently shown whenever the feed attaches
them, which means a rider can be warned about a disruption that ended last
Tuesday. Filtering by impact period is the obvious next step and this is the
predicate for it.

### `RentalVehicle.isAvailable` — `lib/models/transitous/rentals_response.dart:211`

`!isReserved && !isDisabled`.

**Judgement:** keep. The rentals layer draws every vehicle the feed returns,
including ones nobody can take. The moment that is filtered, this is the
filter.

### `Match.addressLine` — `lib/models/transitous/match.dart:134`

Street and house number joined, guarding both empty cases.

**Judgement:** keep. Search results currently show the raw `name`; showing an
address line for address matches is a small, likely improvement, and the
null-handling here is the fiddly part of it.

### `FavoritesService.isFavorite` — `lib/services/favorites_service.dart:206`

Membership test by id.

**Judgement:** borderline, lean keep. `map_screen.dart` answers the same
question with its own `_isFavourite(selection)` against its in-memory list,
which is the right thing on that screen — it must not hit storage per frame.
But any screen without that cached list needs this. Cheap to keep.

### `Environment.planApiVersion` and its five siblings — `lib/environment.dart`

`planApiVersion`, `tripApiVersion`, `stopTimesApiVersion`, `mapTripsApiVersion`,
`mapStopsApiVersion`, `geocodeApiVersion` — each is
`versionFor(TransitousEndpoint.x)`.

**Judgement:** delete the six, keep `versionFor`. They were the API before
`TransitousEndpoint` existed, and every caller now goes through
`versionFor`/`pathFor` directly. Six named getters that each wrap one enum
lookup is a second way to ask the same question, and a seventh endpoint will
not get one. The developer info screen already enumerates
`TransitousEndpoint.values` rather than listing these.

---

## Probably finished with — candidates for deletion

### `FavoritesService.reorderFavorites` — `lib/services/favorites_service.dart:152`

Persists a caller-supplied ordering wholesale. Its `try`/`catch (e) { rethrow; }`
does nothing, which suggests it was written alongside a drag-to-reorder UI
that never shipped.

**Judgement:** could go, but only once someone confirms reordering favourites
is not on the roadmap. Favourites currently sort by insertion, and a
hand-ordered list is a very ordinary thing to want. If it stays, the pointless
`try`/`catch` should go.

### `RecentTripsService.clearHistory` — `lib/services/recent_trips_service.dart:85`

Wipes the recent-trips key.

**Judgement:** keep, and wire it up. There is no way for a user to clear their
recent trips anywhere in Settings, which for a list of journeys someone has
looked up is closer to a gap than to a missing feature. The method is the
easy half of that.


### The no-op unfocus debounce — `lib/screens/map_screen.dart:4084`

Not an unused declaration but dead work. When neither route field has focus,
`_applyFocusState` starts a 100ms timer whose callback is:

```dart
if (!mounted) return;
if (!_fromFocus.hasFocus && !_toFocus.hasFocus) {}
```

An empty `if` body. The timer is created, stored, cancelled in three places
and disposed of, and does nothing at any point. The surrounding early `return`
is what actually matters.

**Judgement:** delete the timer and keep the `return`. The empty body reads
like something was removed and its scaffolding left behind; there is no future
in which an if-statement with no body is what was wanted. Worth a moment
first to check the branch is meant to be a no-op at all, since the alternative
reading is that a behaviour went missing here.

---

## Resolved since the last sweep

- `parseHexColorOr` — `lib/utils/color_utils.dart:22`. Was listed for
  deletion as the unused middle rung between `parseHexColor` and
  `parseHexColorOrAccent`. It now has four callers: every route badge wanted
  exactly `?? AppColors.solidWhite`, and all four were spelling it out. The
  earlier judgement was wrong about which rung was missing a user.
