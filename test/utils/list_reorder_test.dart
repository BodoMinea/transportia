import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/utils/list_reorder.dart';

/// Matched by identity, as the favourites are, so two with one name are
/// still two.
class _Item {
  _Item(this.name);
  final String name;
  @override
  String toString() => name;
}

void main() {
  final a = _Item('a');
  final b = _Item('b');
  final c = _Item('c');
  final d = _Item('d');
  final e = _Item('e');

  List<String> names(List<_Item> items) => [for (final i in items) i.name];

  group('with nothing hidden', () {
    final all = [a, b, c, d];

    test('an item moves down', () {
      expect(names(reorderWithin(all, all, 0, 2)), ['b', 'c', 'a', 'd']);
    });

    test('an item moves up', () {
      expect(names(reorderWithin(all, all, 3, 1)), ['a', 'd', 'b', 'c']);
    });

    test('to the ends', () {
      expect(names(reorderWithin(all, all, 1, 3)), ['a', 'c', 'd', 'b']);
      expect(names(reorderWithin(all, all, 2, 0)), ['c', 'a', 'b', 'd']);
    });

    test('put back where it was, nothing changes', () {
      expect(names(reorderWithin(all, all, 2, 2)), ['a', 'b', 'c', 'd']);
    });
  });

  group('with some hidden', () {
    // The timetable shows only stations: b and d are addresses here.
    final all = [a, b, c, d, e];
    final shown = [a, c, e];

    test('the hidden ones keep their slots', () {
      expect(names(reorderWithin(all, shown, 2, 0)), ['e', 'b', 'a', 'd', 'c']);
      expect(names(reorderWithin(all, shown, 0, 1)), ['c', 'b', 'a', 'd', 'e']);
    });

    test('nothing is lost or doubled', () {
      final reordered = reorderWithin(all, shown, 0, 2);
      expect(reordered.toSet(), all.toSet());
      expect(reordered, hasLength(all.length));
    });
  });

  test('two items with the same name are still two', () {
    final twin = _Item('a');
    final all = [a, b, twin];
    final shown = [a, twin];
    final reordered = reorderWithin(all, shown, 1, 0);
    expect(identical(reordered[0], twin), isTrue);
    expect(identical(reordered[2], a), isTrue);
  });

  test('a single item has nowhere to go', () {
    expect(names(reorderWithin([a], [a], 0, 0)), ['a']);
  });

  test('the list it was given is left alone', () {
    final all = [a, b, c];
    reorderWithin(all, all, 0, 2);
    expect(names(all), ['a', 'b', 'c']);
  });
}
