import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/services/place_bias_service.dart';
import 'package:transportia/utils/place_bias.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    PlaceBiasService.invalidate();
  });

  test('a fresh install starts at the default', () async {
    expect(await PlaceBiasService.load(), PlaceBias.defaultValue);
  });

  test('a changed bias survives a restart', () async {
    await PlaceBiasService.save(3.5);
    PlaceBiasService.invalidate();

    expect(await PlaceBiasService.load(), 3.5);
  });

  test('off survives a restart', () async {
    await PlaceBiasService.save(PlaceBias.off);
    PlaceBiasService.invalidate();

    expect(PlaceBias.isOff(await PlaceBiasService.load()), isTrue);
  });

  test('going back to the default stores nothing', () async {
    await PlaceBiasService.save(3);
    await PlaceBiasService.save(PlaceBias.defaultValue);

    expect(await SharedPreferencesAsync().containsKey('place_bias'), isFalse);
  });

  test('a nonsense stored value falls back to the default', () async {
    await SharedPreferencesAsync().setDouble('place_bias', -4);

    expect(await PlaceBiasService.load(), PlaceBias.defaultValue);
  });
}
