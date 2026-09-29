# Transitous API fixtures

Real responses captured from `api.transitous.org` (MOTIS `v2.11.1`) on
2026-08-08. They exist so model parsing is tested against what the server
actually sends — exponential numbers, absent optional fields and all — rather
than against hand-written JSON that agrees with our assumptions.

| file | request |
|---|---|
| `plan.json` | `/api/v6/plan` Berlin→Hamburg, `withFares`, `detailedTransfers`, `detailedLegs`, `numLegAlternatives=2` |
| `trip.json` | `/api/v6/trip` for a trip taken from `plan.json` |
| `stoptimes.json` | `/api/v6/stoptimes` at Alexanderplatz, `withAlerts`, `fetchStops` |
| `stop.json` | `/api/v6/stop` for Alexanderplatz |
| `geocode.json` | `/api/v1/geocode?text=Alexanderplatz` |
| `reverse_geocode.json` | `/api/v1/reverse-geocode` near Alexanderplatz |
| `geocode_rewe.json` | `/api/v1/geocode?text=Rewe&place=52.52,13.405&placeBias=1.5&numResults=20` (2026-09-28) |
| `geocode_springfield.json` | `/api/v1/geocode?text=Springfield&place=52.52,13.405&placeBias=1.5&numResults=20` (2026-09-28) |
| `geocode_paris.json` | `/api/v1/geocode?text=Paris&place=52.52,13.405&placeBias=1.5&numResults=20` (2026-09-28) |
| `map_initial.json` | `/api/v1/map/initial` — carries `serverConfig` |
| `map_stops.json` | `/api/v1/map/stops` over central Berlin |
| `map_routes.json` | `/api/experimental/map/routes` over central Berlin |
| `one_to_all.json` | `/api/v6/one-to-all` from Alexanderplatz, 15 min |
| `one_to_many.json` | `/api/v1/one-to-many`, walking, `withDistance` |
| `one_to_many_intermodal.json` | `/api/experimental/one-to-many-intermodal` |
| `rentals.json` | `/api/v1/rentals` over central Berlin, all sub-resources |
| `health.json` | `/api/v1/health` |
| `debug_transfers.json` | `/api/debug/transfers` for Alexanderplatz |

## Trimming

Four files were shortened after capture, because the endpoints return far
more than a parser test needs: `map_routes.json` keeps 1 route, 3 polylines
and 5 stops; `one_to_all.json` keeps 30 reachable places; `map_stops.json`
keeps 20 stops; `debug_transfers.json` keeps 5 equivalences and 15
transfers. Nothing else was edited, and no field was removed — array
lengths are the only thing that differs from the wire.

Because of that, do not assert cross-references in `map_routes.json`: its
route no longer indexes the polylines and stops that remain.

## Coordinate formats

The captures record a real inconsistency worth remembering. `/one-to-many`
and `/one-to-many-intermodal` take `lat;lon` and reject `lat,lon`; every other
endpoint takes `lat,lon`. `/rentals` accepts `lat;lon` without complaint and
answers with providers from the wrong region, so getting it backwards there
produces bad data instead of an error.

## Refreshing

Re-capture with the requests above when the API changes. Keep them compact
(`json.dump(..., separators=(',', ':'))`) — they are parser inputs, not
documents meant to be read as diffs.
