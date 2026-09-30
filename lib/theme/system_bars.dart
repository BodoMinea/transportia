import 'package:flutter/services.dart';

/// The status and navigation bars for the app's own background.
///
/// Both bars are transparent and the app draws under them, so their icons sit
/// straight on the app's background: dark icons on the light theme, light on
/// the dark. Fixing them to one brightness left white clock and battery icons
/// on a white screen, which reads as no status bar at all.
///
/// `statusBarBrightness` is iOS's half of the same setting, and it names the
/// background rather than the icons, so it runs the other way round.
SystemUiOverlayStyle systemBarsFor({required bool isDark}) {
  final icons = isDark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: icons,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: const Color(0x00000000),
    systemNavigationBarIconBrightness: icons,
  );
}
