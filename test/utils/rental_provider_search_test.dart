import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/transitous/rentals_response.dart';
import 'package:transportia/utils/rental_provider_search.dart';

RentalProviderGroup _group(String name) =>
    RentalProviderGroup(id: name, name: name);

final _catalogue = [
  _group('Dott paris'),
  _group('Dott berlin'),
  _group('Vélomagg (Montpellier)'),
  _group('nextbike Berlin'),
  _group('Dott munich'),
  const RentalProviderGroup(id: '', name: 'Dott nowhere'),
];

List<String> _names(List<RentalProviderGroup> groups) => [
  for (final g in groups) g.name,
];

void main() {
  test('an empty query suggests nothing', () {
    expect(suggestProviders('', _catalogue), isEmpty);
    expect(suggestProviders('   ', _catalogue), isEmpty);
  });

  test('matches anywhere in the name, ignoring case', () {
    expect(_names(suggestProviders('BERLIN', _catalogue)), [
      'Dott berlin',
      'nextbike Berlin',
    ]);
  });

  test('ignores accents both ways', () {
    expect(_names(suggestProviders('velomagg', _catalogue)), [
      'Vélomagg (Montpellier)',
    ]);
    expect(_names(suggestProviders('vélo', _catalogue)), [
      'Vélomagg (Montpellier)',
    ]);
  });

  test('nearby groups first, then alphabetical', () {
    final names = _names(
      suggestProviders('dott', _catalogue, nearby: {'Dott munich'}),
    );

    expect(names, ['Dott munich', 'Dott berlin', 'Dott paris']);
  });

  test('leaves out picked groups and groups without an id', () {
    final names = _names(
      suggestProviders('dott', _catalogue, picked: {'Dott paris'}),
    );

    expect(names, ['Dott berlin', 'Dott munich']);
  });

  test('stops at the limit', () {
    expect(suggestProviders('t', _catalogue, limit: 2), hasLength(2));
  });

  test('foldForSearch collapses spaces and folds ligatures', () {
    expect(foldForSearch('  Bikesharing   Bolzano '), 'bikesharing bolzano');
    expect(foldForSearch('Straße Œuvre'), 'strasse oeuvre');
  });
}
