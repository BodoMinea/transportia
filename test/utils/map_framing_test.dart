import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/utils/map_framing.dart';

/// The ranked coordinates of a captured search.
List<({LatLng at, String country})> _capture(String name) => [
  for (final m
      in jsonDecode(File('test/fixtures/transitous/$name').readAsStringSync())
          as List)
    (
      at: LatLng(
        ((m as Map)['lat'] as num).toDouble(),
        (m['lon'] as num).toDouble(),
      ),
      country: m['country'] as String? ?? '',
    ),
];

const _phone = Size(400, 700);

void main() {
  group('worldPoint', () {
    test('null island is the middle of the world', () {
      expect(worldPoint(const LatLng(0, 0)), const Offset(256, 256));
    });

    test('the date line is the edge', () {
      // LatLng wraps 180° to -180°, so approach it from inside.
      expect(worldPoint(const LatLng(0, 179.999999)).dx, closeTo(512, 1e-5));
      expect(worldPoint(const LatLng(0, -180)).dx, closeTo(0, 1e-9));
    });

    test('north is up', () {
      expect(worldPoint(const LatLng(52.5, 13.4)).dy, lessThan(256));
    });

    test('fromWorldPoint undoes it', () {
      for (final p in const [
        LatLng(52.52, 13.405),
        LatLng(-33.87, 151.21),
        LatLng(84, -179.9),
      ]) {
        final back = fromWorldPoint(worldPoint(p));
        expect(back.latitude, closeTo(p.latitude, 1e-9));
        expect(back.longitude, closeTo(p.longitude, 1e-9));
      }
    });
  });

  group('MapView.project', () {
    const view = MapView(center: LatLng(0, 0), zoom: 0, size: Size(400, 400));

    test('the centre is drawn in the middle', () {
      expect(view.project(const LatLng(0, 0)), const Offset(200, 200));
    });

    test('a quarter of the world east is a quarter of 512 px right', () {
      expect(view.project(const LatLng(0, 90)).dx, closeTo(328, 1e-9));
    });

    test('each zoom level doubles distances', () {
      const zoomed = MapView(
        center: LatLng(0, 0),
        zoom: 1,
        size: Size(400, 400),
      );
      expect(zoomed.project(const LatLng(0, 90)).dx, closeTo(456, 1e-9));
    });

    test('facing east, what is east is drawn above', () {
      const facingEast = MapView(
        center: LatLng(0, 0),
        zoom: 0,
        size: Size(400, 400),
        bearing: 90,
      );
      final p = facingEast.project(const LatLng(0, 90));
      expect(p.dx, closeTo(200, 1e-9));
      expect(p.dy, closeTo(72, 1e-9));
    });

    test('across the date line is the short way round', () {
      const fiji = MapView(
        center: LatLng(-17, 179),
        zoom: 4,
        size: Size(400, 400),
      );
      // Two degrees east, not 358 degrees west.
      final p = fiji.project(const LatLng(-17, -179));
      expect(p.dx, greaterThan(200));
      expect(p.dx, lessThan(300));
    });
  });

  group('weightedSpread', () {
    test('nothing to spread is null', () {
      expect(weightedSpread(const []), isNull);
      expect(weightedSpread(const [(Offset(1, 1), 0.0)]), isNull);
    });

    test('one point has no spread', () {
      final s = weightedSpread(const [(Offset(3, 4), 1.0)])!;
      expect(s.mean, const Offset(3, 4));
      expect(s.sigma, Offset.zero);
    });

    test('equal weights give the plain mean and σ', () {
      final s = weightedSpread(const [
        (Offset(0, 0), 1.0),
        (Offset(2, 6), 1.0),
      ])!;
      expect(s.mean, const Offset(1, 3));
      expect(s.sigma.dx, closeTo(1, 1e-12));
      expect(s.sigma.dy, closeTo(3, 1e-12));
    });

    test('a heavier point pulls the mean and matches the two-pass sum', () {
      // Mean 1; variance (3·1² + 1·3²) / 4 = 3.
      final s = weightedSpread(const [
        (Offset(0, 0), 3.0),
        (Offset(4, 0), 1.0),
      ])!;
      expect(s.mean.dx, closeTo(1, 1e-12));
      expect(s.sigma.dx, closeTo(math.sqrt(3), 1e-12));
    });

    test('points close together far from zero lose no precision', () {
      // Where a naive sum of squares cancels to nothing.
      final s = weightedSpread(const [
        (Offset(1e8, 0), 1.0),
        (Offset(1e8 + 2, 0), 1.0),
      ])!;
      expect(s.sigma.dx, closeTo(1, 1e-6));
    });
  });

  group('leadingGroup', () {
    test('nothing, and one result', () {
      expect(leadingGroup(const []), isEmpty);
      expect(leadingGroup(const [LatLng(52.5, 13.4)]), [0]);
    });

    test('Paris: the city and its stations, not the US towns', () {
      final paris = _capture('geocode_paris.json');
      final group = leadingGroup([for (final r in paris) r.at]);

      expect(group, contains(0));
      expect(group.map((i) => paris[i].country).toSet(), {'FR'});
      // The city, Paris-Est and Paris-Nord.
      expect(group, hasLength(3));
    });

    test('Springfield: a lone #1 takes its peers along', () {
      // Ten Springfields across the US, all as good as each other.
      final springfield = _capture('geocode_springfield.json');
      final group = leadingGroup([for (final r in springfield) r.at]);

      expect(group.length, greaterThan(5));
      expect(group.map((i) => springfield[i].country).toSet(), {'US'});
    });

    test('Rewe: every one of the top ten is in Berlin together', () {
      final rewe = _capture('geocode_rewe.json');
      expect(leadingGroup([for (final r in rewe) r.at]), hasLength(10));
    });

    test('only the top ten decide', () {
      final many = [for (var i = 0; i < 30; i++) LatLng(52.5, 13.4 + i * 1e-4)];
      expect(leadingGroup(many), hasLength(10));
    });
  });

  group('frameResults', () {
    const padding = EdgeInsets.all(40);

    MapView viewOf(MapFrame frame) =>
        MapView(center: frame.center, zoom: frame.zoom, size: _phone);

    test('nothing to frame is null', () {
      expect(frameResults(const [], _phone, maxZoom: 16), isNull);
    });

    test('one result is shown at the closest zoom its kind allows', () {
      final frame = frameResults(
        const [LatLng(52.53, 13.41)],
        _phone,
        maxZoom: 16,
      )!;
      expect(frame.zoom, 16);
      expect(frame.center.latitude, closeTo(52.53, 1e-9));
    });

    test('Paris opens on Paris', () {
      final paris = [for (final r in _capture('geocode_paris.json')) r.at];
      final frame = frameResults(paris, _phone, maxZoom: 16, padding: padding)!;

      final view = viewOf(frame);
      expect((Offset.zero & _phone).contains(view.project(paris[0])), isTrue);
      // Close enough to tell the two stations apart.
      expect(frame.zoom, greaterThan(11));
      // Texas is not on screen.
      expect((Offset.zero & _phone).contains(view.project(paris[2])), isFalse);
    });

    test('Springfield opens on the continent, #1 in view', () {
      final springfield = [
        for (final r in _capture('geocode_springfield.json')) r.at,
      ];
      final frame = frameResults(
        springfield,
        _phone,
        maxZoom: 12,
        padding: padding,
      )!;

      expect(frame.zoom, lessThan(5));
      final first = viewOf(frame).project(springfield.first);
      expect((Offset.zero & _phone).contains(first), isTrue);
    });

    test('never closer than the kind of place allows', () {
      final twoDoors = [
        const LatLng(52.5300, 13.4100),
        const LatLng(52.5301, 13.4101),
      ];
      final frame = frameResults(twoDoors, _phone, maxZoom: 15)!;
      expect(frame.zoom, 15);
    });
  });

  group('fitAll', () {
    test('nothing to fit is null', () {
      expect(fitAll(const [], _phone, maxZoom: 16), isNull);
    });

    test('every point lands inside the padding', () {
      final us = [
        for (final r in _capture('geocode_paris.json'))
          if (r.country == 'US') r.at,
      ];
      const padding = EdgeInsets.all(40);
      final frame = fitAll(us, _phone, maxZoom: 16, padding: padding)!;
      final view = MapView(
        center: frame.center,
        zoom: frame.zoom,
        size: _phone,
      );
      final inside = padding.deflateRect(Offset.zero & _phone).inflate(0.5);
      for (final p in us) {
        expect(inside.contains(view.project(p)), isTrue, reason: '$p');
      }
    });

    test('one point is shown at the closest zoom', () {
      final frame = fitAll(const [LatLng(1, 2)], _phone, maxZoom: 14)!;
      expect(frame.zoom, 14);
    });
  });

  group('edgeArrows', () {
    const area = Rect.fromLTWH(0, 0, 400, 400);

    test('nothing off screen, no arrows', () {
      expect(
        edgeArrows(const [Offset(10, 10), Offset(390, 390)], area),
        isEmpty,
      );
    });

    test('two points the same way share one arrow at their mean', () {
      final arrows = edgeArrows(const [
        Offset(-100, 180),
        Offset(-100, 220),
        Offset(200, 200),
      ], area);
      expect(arrows, hasLength(1));
      expect(arrows.single.members, unorderedEquals([0, 1]));
      expect(arrows.single.isSeveral, isTrue);
      expect(arrows.single.angle.abs(), closeTo(math.pi, 1e-9));
      expect(arrows.single.edge.dx, closeTo(0, 1e-9));
    });

    test('points either side of due west still share one arrow', () {
      // Just above and just below the ±180° seam.
      final arrows = edgeArrows(const [
        Offset(-500, 190),
        Offset(-500, 210),
      ], area);
      expect(arrows, hasLength(1));
      expect(arrows.single.angle.abs(), closeTo(math.pi, 1e-9));
    });

    test('points apart keep their own arrows, at their true angles', () {
      final arrows = edgeArrows(const [
        Offset(900, 200),
        Offset(200, -900),
      ], area);
      expect(arrows, hasLength(2));
      final angles = arrows.map((a) => a.angle).toList()..sort();
      expect(angles.first, closeTo(-math.pi / 2, 1e-9));
      expect(angles.last, closeTo(0, 1e-9));
      expect(arrows.every((a) => !a.isSeveral), isTrue);
    });

    test('an arrow off the diagonal is not snapped to it', () {
      final arrow = edgeArrows(const [Offset(900, 400)], area).single;
      expect(arrow.angle, closeTo(math.atan2(200, 700), 1e-9));
    });
  });

  group('edgePoint', () {
    const area = Rect.fromLTWH(0, 0, 400, 200);

    test('straight out through each side', () {
      expect(edgePoint(area, 0), const Offset(400, 100));
      final up = edgePoint(area, -math.pi / 2);
      expect(up.dx, closeTo(200, 1e-9));
      expect(up.dy, closeTo(0, 1e-9));
    });

    test('a diagonal leaves through the nearer side', () {
      final p = edgePoint(area, math.pi / 4);
      expect(p.dy, closeTo(200, 1e-9));
      expect(p.dx, closeTo(300, 1e-9));
    });
  });

  group('firstFreeRect', () {
    const size = Size(20, 10);

    test('takes the first spot nothing covers', () {
      final rect = firstFreeRect(
        const [Offset(10, 5), Offset(50, 5)],
        size,
        [const Rect.fromLTWH(0, 0, 30, 10)],
      );
      expect(rect.center, const Offset(50, 5));
    });

    test('with every spot covered, keeps the first', () {
      final rect = firstFreeRect(
        const [Offset(10, 5), Offset(50, 5)],
        size,
        [const Rect.fromLTWH(0, 0, 100, 100)],
      );
      expect(rect.center, const Offset(10, 5));
    });
  });

  group('boundsOf', () {
    test('nothing has no bounds', () {
      expect(boundsOf(const []), isNull);
    });

    test('one point is a box of no size', () {
      final b = boundsOf(const [LatLng(52.5, 13.4)])!;
      expect(b.southwest, const LatLng(52.5, 13.4));
      expect(b.northeast, const LatLng(52.5, 13.4));
    });

    test('corners from the extremes, whatever the order', () {
      final b = boundsOf(const [
        LatLng(52.6, 13.3),
        LatLng(52.4, 13.5),
        LatLng(52.5, 13.4),
      ])!;
      expect(b.southwest, const LatLng(52.4, 13.3));
      expect(b.northeast, const LatLng(52.6, 13.5));
      final c = boundsCenter(b);
      expect(c.latitude, closeTo(52.5, 1e-9));
      expect(c.longitude, closeTo(13.4, 1e-9));
    });
  });
}
