import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:transportia/utils/polyline_utils.dart';

/// The standard documented example, at the precision it is written in.
const String _googleExample = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

void main() {
  group('encodePolyline', () {
    test('writes the documented example', () {
      final points = decodePolyline(_googleExample, 5);

      expect(points, hasLength(3));
      expect(encodePolyline(points, 5), _googleExample);
    });

    test('survives being decoded again at the precision of the planner', () {
      final points = [
        const LatLng(52.525123, 13.369456),
        const LatLng(52.520001, 13.405002),
        const LatLng(52.366, 13.503),
      ];

      final decoded = decodePolyline(encodePolyline(points, 6), 6);

      expect(decoded, hasLength(3));
      for (var i = 0; i < points.length; i++) {
        expect(decoded[i].latitude, closeTo(points[i].latitude, 1e-6));
        expect(decoded[i].longitude, closeTo(points[i].longitude, 1e-6));
      }
    });

    test('is empty for no points', () {
      expect(encodePolyline(const [], 6), isEmpty);
    });
  });

  group('slicePolyline', () {
    const line = [
      LatLng(0, 0),
      LatLng(0, 1),
      LatLng(0, 2),
      LatLng(0, 3),
      LatLng(0, 4),
    ];

    test('keeps the points from the one nearest the start to the end', () {
      final sliced = slicePolyline(
        line,
        const LatLng(0.1, 1.1),
        const LatLng(0, 3.2),
      );

      expect(sliced, [line[1], line[2], line[3]]);
    });

    test('keeps the ends themselves', () {
      final sliced = slicePolyline(line, line.first, line.last);

      expect(sliced, line);
    });

    test('is null when the ends are the wrong way round', () {
      expect(slicePolyline(line, line[3], line[1]), isNull);
    });

    test('is null when both ends are the same place', () {
      expect(slicePolyline(line, line[2], line[2]), isNull);
    });

    test('is null when there is no line to cut', () {
      expect(slicePolyline(const [], line[0], line[1]), isNull);
      expect(slicePolyline(const [LatLng(0, 0)], line[0], line[1]), isNull);
    });
  });
}
