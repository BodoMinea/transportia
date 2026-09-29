import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/screens/map_place_picker/edge_tabs.dart';
import 'package:transportia/screens/map_place_picker/result_pins.dart';
import 'package:transportia/services/transitous_geocode_service.dart';
import 'package:transportia/utils/map_framing.dart';

const _size = Size(400, 600);
const _berlin = LatLng(52.52, 13.405);

Future<List<List<int>>> _pump(
  WidgetTester tester,
  List<LatLng> targets, {
  List<Rect> taken = const [],
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final taps = <List<int>>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: EdgeTabsLayer(
        view: const MapView(center: _berlin, zoom: 12, size: _size),
        targets: targets,
        area: Offset.zero & _size,
        taken: taken,
        onTap: taps.add,
      ),
    ),
  );
  return taps;
}

void main() {
  group('EdgeTabsLayer', () {
    testWidgets('nothing off screen, no tabs', (tester) async {
      await _pump(tester, const [_berlin, LatLng(52.521, 13.406)]);
      expect(find.byType(EdgeTab), findsNothing);
    });

    testWidgets('one result off screen: a plain tab with its distance', (
      tester,
    ) async {
      // Potsdam, 27 km south-west.
      await _pump(tester, const [_berlin, LatLng(52.39, 13.06)]);

      final tab = tester.widget<EdgeTab>(find.byType(EdgeTab));
      expect(tab.several, isFalse);
      expect(find.text('27 km'), findsOne);
    });

    testWidgets('two the same way: one stacked tab, nearest distance', (
      tester,
    ) async {
      await _pump(tester, const [LatLng(52.39, 13.06), LatLng(52.38, 13.04)]);

      expect(find.byType(EdgeTab), findsOne);
      expect(tester.widget<EdgeTab>(find.byType(EdgeTab)).several, isTrue);
      expect(find.text('27 km'), findsOne);
    });

    testWidgets('tapping a tab or its distance gives what it stands for', (
      tester,
    ) async {
      final taps = await _pump(tester, const [
        _berlin,
        LatLng(52.39, 13.06),
        LatLng(52.38, 13.04),
        // Hamburg, the other way.
        LatLng(53.55, 10.0),
      ]);

      await tester.tap(find.text('27 km'));
      expect(taps.single, unorderedEquals([1, 2]));

      await tester.tap(find.bySemanticsLabel('Show results 255 km away'));
      expect(taps.last, [3]);
    });

    testWidgets('a distance steps aside from what is drawn there', (
      tester,
    ) async {
      final free = await _labelRect(tester, const []);
      final blocked = await _labelRect(tester, [free.inflate(2)]);

      expect(blocked.overlaps(free), isFalse);
    });
  });

  group('resultPinFeatures', () {
    TransitousLocationSuggestion result(String name, String type) =>
        TransitousLocationSuggestion(
          id: name,
          name: name,
          lat: 52.5,
          lon: 13.4,
          type: type,
        );

    test('one feature per result, found again by rank', () {
      final features =
          resultPinFeatures([
                result('REWE', 'PLACE'),
                result('Ostkreuz', 'STOP'),
              ])['features']
              as List;

      expect(features, hasLength(2));
      final second = features[1] as Map;
      expect((second['properties'] as Map)['rank'], 1);
      expect((second['properties'] as Map)['name'], 'Ostkreuz');
      expect((second['geometry'] as Map)['coordinates'], [13.4, 52.5]);
    });

    test('the selected pin is marked and drawn first', () {
      final features =
          resultPinFeatures([
                result('A', 'PLACE'),
                result('B', 'PLACE'),
              ], selected: 1)['features']
              as List;
      final props = [for (final f in features) (f as Map)['properties'] as Map];

      expect(props[0]['selected'], isFalse);
      expect(props[1]['selected'], isTrue);
      expect(props[1]['sortKey'], lessThan(props[0]['sortKey'] as num));
    });

    test('drawn with the icon the list uses', () {
      final place = result('REWE', 'PLACE');
      final props =
          ((resultPinFeatures([place])['features'] as List).single
                  as Map)['properties']
              as Map;
      expect(props['icon'], resultPinImageId(resultPinIcon(place)));
    });

    test('no results, no features', () {
      expect(resultPinFeatures(const [])['features'], isEmpty);
    });
  });

  group('resultRankOf', () {
    test('a pin reports the rank it was given', () {
      expect(resultRankOf('0', 3), 0);
      expect(resultRankOf('2', 3), 2);
    });

    test('anything else is no result', () {
      expect(resultRankOf('3', 3), isNull);
      expect(resultRankOf('-1', 3), isNull);
      expect(resultRankOf('abc', 3), isNull);
      expect(resultRankOf('', 3), isNull);
      expect(resultRankOf('0', 0), isNull);
    });
  });
}

Future<Rect> _labelRect(WidgetTester tester, List<Rect> taken) async {
  await _pump(tester, const [LatLng(52.39, 13.06)], taken: taken);
  return tester.getRect(find.text('27 km'));
}
