import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/itinerary_map_screen.dart';

final DateTime _t0 = DateTime(2026, 6, 1, 10, 0);

String _at(int minutes) =>
    _t0.add(Duration(minutes: minutes)).toUtc().toIso8601String();

Map<String, dynamic> _place(String name, {String? track}) => {
  'name': name,
  'lat': 49.0 + name.length / 100,
  'lon': 8.0 + name.length / 100,
  'track': ?track,
};

/// Late everywhere, a long headsign, and a change with no platform: every
/// card at its tallest.
Itinerary _lateJourney() => Itinerary.fromJson({
  'duration': 95 * 60,
  'startTime': _at(0),
  'endTime': _at(95),
  'transfers': 1,
  'legs': [
    {
      'mode': 'HIGHSPEED_RAIL',
      'startTime': _at(6),
      'endTime': _at(46),
      'scheduledStartTime': _at(5),
      'scheduledEndTime': _at(40),
      'duration': 2400,
      'realTime': true,
      'displayName': 'ICE 594',
      'headsign': 'Berlin Hauptbahnhof via Frankfurt (Main) Flughafen',
      'from': {
        ..._place('Stuttgart Hbf', track: '8'),
        'departure': _at(6),
        'scheduledDeparture': _at(5),
      },
      'to': {
        ..._place('Mannheim Hbf'),
        'arrival': _at(46),
        'scheduledArrival': _at(40),
      },
    },
    {
      'mode': 'WALK',
      'startTime': _at(46),
      'endTime': _at(52),
      'scheduledStartTime': _at(40),
      'scheduledEndTime': _at(46),
      'duration': 360,
      'distance': 280.0,
      'from': {
        ..._place('Mannheim Hbf'),
        'arrival': _at(46),
        'scheduledArrival': _at(40),
      },
      'to': _place('Mannheim Hbf Gleis 4'),
    },
    {
      'mode': 'REGIONAL_RAIL',
      'startTime': _at(57),
      'endTime': _at(95),
      'scheduledStartTime': _at(55),
      'scheduledEndTime': _at(93),
      'duration': 2280,
      'realTime': true,
      'displayName': 'RE 10a',
      'headsign': 'Heidelberg Hbf',
      'from': {
        ..._place('Mannheim Hbf Gleis 4', track: '4'),
        'departure': _at(57),
        'scheduledDeparture': _at(55),
      },
      'to': {
        ..._place('Heidelberg Hbf', track: '2'),
        'arrival': _at(95),
        'scheduledArrival': _at(93),
      },
    },
  ],
});

Future<void> _pumpPage(WidgetTester tester, int? legIndex) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // The map asks for a native view; leave it pending so the rest draws.
  const channel = SystemChannels.platform_views;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    channel,
    (call) => call.method == 'create'
        ? Completer<Object?>().future
        : Future<Object?>.value(),
  );
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(1.3),
        ),
        child: WidgetsApp(
          color: const Color(0xFFFFFFFF),
          localizationsDelegates: const [
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, _, _) => ItineraryMapScreen(
              itinerary: _lateJourney(),
              initialLegIndex: legIndex,
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // Overflow is reported as an exception, so a clean pump is the assertion.
  for (final (legIndex, name) in [
    (null, 'the overview'),
    (0, 'a late train'),
    (1, 'a change with no platform'),
  ]) {
    testWidgets('delays under the times fit on $name at 360 and 1.3x text', (
      tester,
    ) async {
      await _pumpPage(tester, legIndex);
      expect(tester.takeException(), isNull);
      expect(find.text('+6m'), findsWidgets);
    });
  }
}
