import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/theme/system_bars.dart';

void main() {
  test('the light theme gets dark icons, so they show on white', () {
    final style = systemBarsFor(isDark: false);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    // iOS names the background, not the icons.
    expect(style.statusBarBrightness, Brightness.light);
  });

  test('the dark theme gets light icons', () {
    final style = systemBarsFor(isDark: true);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });

  test('both bars stay transparent over the app', () {
    for (final isDark in [false, true]) {
      final style = systemBarsFor(isDark: isDark);
      expect(style.statusBarColor, const Color(0x00000000));
      expect(style.systemNavigationBarColor, const Color(0x00000000));
    }
  });
}
