import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/rental_provider_prefs.dart';

const _voi = PickedProviderGroup(id: 'Voi Technology AB', name: 'Voi');
const _dott = PickedProviderGroup(id: 'Dott berlin', name: 'Dott berlin');

void main() {
  test('nothing picked limits nothing, whatever the switch says', () {
    const prefs = RentalProviderPrefs(limit: true);

    expect(prefs.isActive, isFalse);
    expect(prefs.activeGroupIds, isEmpty);
  });

  test('picks are sent only while the limit is on', () {
    const off = RentalProviderPrefs(groups: [_voi, _dott]);

    expect(off.activeGroupIds, isEmpty);
    expect(off.withLimit(true).activeGroupIds, [_voi.id, _dott.id]);
  });

  test('the first pick turns the limit on, later ones leave it', () {
    final first = RentalProviderPrefs.none.add(_voi);
    expect(first.limit, isTrue);

    final second = first.withLimit(false).add(_dott);
    expect(second.limit, isFalse);
  });

  test('picking the same group twice keeps one', () {
    final prefs = RentalProviderPrefs.none.add(_voi).add(_voi);

    expect(prefs.groups, hasLength(1));
  });

  test('removing the last pick turns the limit off', () {
    final prefs = RentalProviderPrefs.none.add(_voi).add(_dott);

    expect(prefs.remove(_voi.id).limit, isTrue);
    expect(prefs.remove(_voi.id).remove(_dott.id).limit, isFalse);
  });

  test('survives a round trip through JSON', () {
    final prefs = RentalProviderPrefs.none.add(_voi).add(_dott);
    final back = RentalProviderPrefs.fromJson(prefs.toJson());

    expect(back.limit, isTrue);
    expect([for (final g in back.groups) g.id], [_voi.id, _dott.id]);
    expect(back.groups.first.name, 'Voi');
  });

  test('skips unreadable entries rather than dropping everything', () {
    final prefs = RentalProviderPrefs.fromJson({
      'limit': true,
      'groups': [
        {'id': 'Dott berlin', 'name': 'Dott berlin'},
        {'id': ''},
        'nonsense',
        {'id': 'VOI'},
      ],
    });

    expect([for (final g in prefs.groups) g.id], ['Dott berlin', 'VOI']);
    expect(prefs.groups.last.name, 'VOI');
  });
}
