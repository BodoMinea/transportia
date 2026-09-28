# Nominatim fixtures

Real responses from `nominatim.openstreetmap.org` captured on 2026-09-28, so
the place details parser is tested against what the server sends.

| file | request |
|---|---|
| `lookup_rewe.json` | `/lookup?osm_ids=N318349843&format=jsonv2&extratags=1&addressdetails=1` — a shop node with opening hours |
| `lookup_mcdonalds.json` | the same for `N578429141` — `contact:` keys, a floor, no opening hours |
| `lookup_kadewe.json` | the same for `W60541581` — a building way |

The data is © OpenStreetMap contributors, under the ODbL.

Re-capture with an app-identifying User-Agent and no more than one request
a second; see the Nominatim usage policy.
