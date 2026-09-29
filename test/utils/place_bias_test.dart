import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/place_bias.dart';

void main() {
  group('PlaceBias slider', () {
    test('the first stop is off', () {
      expect(PlaceBias.fromPosition(0), PlaceBias.off);
      expect(PlaceBias.toPosition(PlaceBias.off), 0);
      expect(PlaceBias.isOff(PlaceBias.fromPosition(0)), isTrue);
    });

    test('the default sits on a stop of its own', () {
      final position = PlaceBias.toPosition(PlaceBias.defaultValue);

      expect(PlaceBias.fromPosition(position), PlaceBias.defaultValue);
      expect(PlaceBias.isDefault(PlaceBias.fromPosition(position)), isTrue);
    });

    test('the last stop is the strongest bias offered', () {
      expect(PlaceBias.fromPosition(PlaceBias.positions), PlaceBias.max);
      expect(PlaceBias.toPosition(PlaceBias.max), PlaceBias.positions);
    });

    test('every stop reads back to itself', () {
      for (var p = 0; p <= PlaceBias.positions; p++) {
        expect(PlaceBias.toPosition(PlaceBias.fromPosition(p)), p);
      }
    });

    test('values outside the range land on the nearest end', () {
      expect(PlaceBias.toPosition(20), PlaceBias.positions);
      expect(PlaceBias.toPosition(0.1), 1);
      expect(PlaceBias.fromPosition(99), PlaceBias.max);
      expect(PlaceBias.fromPosition(-3), PlaceBias.off);
    });
  });
}
