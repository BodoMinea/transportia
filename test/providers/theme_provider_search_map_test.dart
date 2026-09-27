import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/providers/theme_provider.dart';

/// Literal, as a released build will have written it.
const String _searchMapEnabled = 'search_map_enabled';

Future<ThemeProvider> _loaded() async {
  final provider = ThemeProvider();
  while (!provider.isInitialized) {
    await Future<void>.delayed(Duration.zero);
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the map is on unless the rider turned it off', () async {
    final provider = await _loaded();

    expect(provider.searchMapEnabled, isTrue);
    expect(provider.showsSearchMap, isTrue);
  });

  test('no map is shown before the setting has been read', () {
    // Even where it is on: building the map is what downloads it, and a
    // rider who turned it off must not pay for one on every launch.
    final provider = ThemeProvider();

    expect(provider.isInitialized, isFalse);
    expect(provider.showsSearchMap, isFalse);
  });

  test('a stored "off" is honoured', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({_searchMapEnabled: false});

    final provider = await _loaded();

    expect(provider.searchMapEnabled, isFalse);
    expect(provider.showsSearchMap, isFalse);
  });

  test('turning it off is stored and announced', () async {
    final provider = await _loaded();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setSearchMapEnabled(false);

    expect(provider.showsSearchMap, isFalse);
    expect(notified, 1);
    expect(await SharedPreferencesAsync().getBool(_searchMapEnabled), isFalse);
  });

  test('setting the same value again does nothing', () async {
    final provider = await _loaded();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setSearchMapEnabled(true);

    expect(notified, 0);
  });
}
