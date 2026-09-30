# Why the place search uses `placeBias=1.5`

`/geocode` takes a coordinate (`place`) and a strength (`placeBias`, default
1) and ranks results by a mix of text relevance and nearness. The app sends
the rider's position as `place`. This file records how the strength was
chosen, so it is not re-litigated by feel.

Measured 2026-09-28 against `api.transitous.org` (`/api/v1/geocode`), from
Berlin (`52.52,13.405`). Results are live data and drift; re-run before
trusting a number here (see the end).

## The problem

The app used `placeBias=5`. At that strength nearness outweighs everything, so
a far-away but obviously right answer never surfaces:

- `Paris` returned ten Berlin shops and bars with "Paris" in the name; the
  city and its stations were absent.
- `Hamburg`, `Köln`, `Leipzig` put a nearby shop ahead of the city's main
  station.
- `Hauptbahnhof` listed hotels and a car park after Berlin Hbf, instead of
  other cities' Hbf.

The opposite failure is a strength too low: `Lidl` puts a bus stop in the UK
first, because a stop literally named "Lidl" matches the text as well as a
shop does.

## What was tried

Parameters of `/geocode` (from MOTIS's `openapi.yaml`): `text`, `language`,
`type`, `mode`, `place`, `placeBias`, `numResults`, `min`/`max`.

| Parameter | Effect on ranking |
|---|---|
| `placeBias` | The one lever. Swept below. |
| `mode=LONG_DISTANCE,HIGHSPEED_RAIL` | Filters stops only; places stay and nothing is reordered. No help for `Paris`. |
| `language=de` | No change. |
| `type` | Filters; does not rank. |
| `numResults` | Honoured up to at least 100. Same order, more appended. |
| `min`/`max` | A hard bounding box, the opposite of what `Paris` needs. |

There is no parameter for a station's importance. MOTIS applies it itself:
stops carry an `importance` and `modes`, and ranking already uses them, which
is why `Köln` puts Köln Hbf second at a moderate bias.

## `placeBias` sweep

First results, from Berlin. "Stations" means the long-distance stops.

| Query | 1 | **1.5** | 2 | 2.5–3 | 4–5 (5 was the old value) |
|---|---|---|---|---|---|
| Paris | city, Paris-Est, US towns | **city, Paris-Est, Paris-Nord** within the first four | city, Est, two Berlin shops, Nord | city, Berlin shops, Est from #7 | Berlin shops first; city at #3 (4) or absent (5) |
| Hamburg | city, four stations | same | same | not measured | city, two Berlin shops, stations |
| Köln, Leipzig | city, Hbf | same | same | not measured | Berlin shop at #3–4 |
| Hauptbahnhof | Berlin Hbf, other cities' Hbf | same | same | not measured | Berlin Hbf, then hotels and a car park |
| Springfield | US cities | US cities | US cities | not measured | UK bus stops |
| Lidl | UK stop first | local; UK stop at #6 | all local | not measured | all local |
| Rewe, McDonald's, Alexanderplatz, Hermannplatz | local | local | local | local | local |
| `McDonalds` (no apostrophe) | UK and CA stops | UK and CA stops | UK and CA stops | UK and CA stops | local only from about 4.8 |

## Why 1.5

Of the values measured (1, 1.5, 2, 2.5, 3, 4, 4.5, 4.8, 5), it is the only
one where `Paris` returns the city and both Paris stations ahead of every
Berlin result; the first Berlin one comes at #13. At 1 Paris-Nord drops out
of the first eight; at 2 two Berlin shops already sit between Paris-Est and
Paris-Nord; from 2.5 on they crowd the stations further down.

`Hamburg`, `Köln`, `Leipzig` and `Hauptbahnhof` come out right at 1 to 2 and
wrong at 5, so they rule out the old value without telling 1, 1.5 and 2
apart.

What it costs, honestly:

- `Lidl` lets one far-away stop into the first ten (at #6). At 1 it leads;
  at 2 it is gone.
- `McDonalds` typed without the apostrophe finds bus stops, not restaurants,
  at every strength up to about 4.5. This is MOTIS's text matching: the
  stops are named exactly that. It is not fixable with the bias, and it is
  not worth 5 to fix it, because that brings back the `Paris` problem. The
  spelling with the apostrophe is fine at every strength.

## The rider's own setting

1.5 is the default, not a fixed value: *Search and routing options* has a
slider from 0.5 to 5 in steps of 0.5 (`PlaceBias` in
`lib/utils/place_bias.dart`), stored as `place_bias` and left unstored at
the default so a better-measured default still reaches everyone who never
moved it. Moving off 1.5 shows a one-line reason for it on the screen.

The slider's first stop is off. Then no `place` is sent with a search at
all, only the text; `TransitousGeocodeService.fetchSuggestionPage` enforces
this for every caller. "Search in this area" is not affected: its point is
the map's centre, picked by the rider, not their position.

## "Search in this area": `placeBias=20`

The map picker's "Search in this area" asks again from the map's centre,
where the rider has panned to on purpose, so nearness should win outright.
Measured 2026-09-29, 20 results from each centre, counting results within
15 km:

| Query, map centred on | 1.5 | 5 | 10 | **20** | 50 | 100 |
|---|---|---|---|---|---|---|
| McDonalds, Paris | 0 | 17 | 20 | **20** | 20 | 20 |
| Rewe, Hamburg | 20 | 20 | 20 | **20** | 20 | 20 |
| Hauptbahnhof, München | 1 | 12 | 12 | **12** | 12 | 12 |
| Paris, Berlin | 1 | 14 | 15 | **15** | 15 | 15 |
| Lidl, Köln | 19 | 20 | 20 | **20** | 20 | 20 |
| Springfield, Springfield IL | 6 | 20 | 20 | **20** | 20 | 20 |
| Bahnhof, Zürich | 4 | 14 | 20 | **20** | 20 | 20 |

20 is where every query stops changing: nothing moves between 20 and 100.
From 10 to 20 the order still improves (for `Bahnhof` in Zürich, the two
stations 1–2 km away rise above ones 6–9 km out). Names keep matching: 19
or 20 of 20 contain the query at every strength.

A strong bias does not restrict. Where nothing matches nearby (`Rewe` from
Paris) the results simply come from further away, and the edge tabs point
to them; a bounding box (`min`/`max`) would return nothing instead.

## Not solved here

Reported upstream rather than patched in the app:

- `McDonalds` without the apostrophe (above).
- `Hamburg` lists Hamburg Hbf as "ZOB Hamburg".
- `Paris` returns only Paris-Est and Paris-Nord; Gare de Lyon and
  Montparnasse appear only when named.

## Re-running

```sh
for b in 1 1.5 2 5; do
  curl -sG -A transportia-test https://api.transitous.org/api/v1/geocode \
    --data-urlencode "text=Paris" \
    --data "place=52.52,13.405&placeBias=$b&numResults=10" |
    python3 -c 'import sys,json; print([(m["type"][0], m["name"], m.get("country")) for m in json.load(sys.stdin)][:6])'
done
```

Change the bias only if the queries above get clearly worse or better, and
update this file with the new table.
