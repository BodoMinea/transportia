import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'package:transportia/models/journey_stop.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/utils/vehicle_position.dart';
import 'package:transportia/widgets/journey/trip_timeline.dart';
import 'package:transportia/widgets/timeline_indicator_box.dart';

/// A trip seen from inside a journey that rides only part of it: the stops
/// and the line outside that stretch are drawn light.
const Color _route = Color(0xFF1E88E5);
final DateTime _departure = DateTime.utc(2026, 6, 1, 10);

JourneyStop _stop(int index) {
  final at = _departure.add(Duration(minutes: index * 10));
  return JourneyStop(
    name: 'Stop $index',
    stopId: 'stop-$index',
    lat: 0,
    lon: 0,
    arrival: index == 0 ? null : at,
    departure: index == 4 ? null : at,
    scheduledArrival: index == 0 ? null : at,
    scheduledDeparture: index == 4 ? null : at,
    track: null,
    scheduledTrack: null,
    cancelled: false,
    alerts: const [],
  );
}

final List<JourneyStop> _stops = [for (var i = 0; i < 5; i++) _stop(i)];

Future<void> _pump(
  WidgetTester tester, {
  ({int start, int end})? ridden,
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: WidgetsApp(
        color: const Color(0xFF000000),
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        supportedLocales: const [Locale('en', 'US')],
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (_, _, _) => SingleChildScrollView(
            child: TripTimeline(
              stops: _stops,
              // Before the trip starts, so nothing is dimmed for being passed.
              position: estimateVehiclePosition(
                _stops,
                now: now ?? _departure.subtract(const Duration(hours: 1)),
              ),
              routeColor: _route,
              routeTextColor: const Color(0xFFFFFFFF),
              modeIcon: LucideIcons.trainFront,
              isLive: true,
              onStopTap:
                  ({
                    required String? stopId,
                    required String stopName,
                    required DateTime referenceTime,
                  }) {},
              riddenRange: ridden,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Color> _dotColors(WidgetTester tester) => [
  for (final dot in tester.widgetList<DotIndicator>(find.byType(DotIndicator)))
    dot.color!,
];

/// The line between each two stops. The timeline draws each of them twice, as
/// the end of one tile and the start of the next, so the two are taken once.
List<Color> _lineColors(WidgetTester tester) {
  final drawn = [
    for (final line in tester.widgetList<SolidLineConnector>(
      find.byType(SolidLineConnector),
    ))
      line.color!,
  ];
  for (var i = 0; i < drawn.length; i += 2) {
    expect(drawn[i], drawn[i + 1], reason: 'the two draws of one line agree');
  }
  return [for (var i = 0; i < drawn.length; i += 2) drawn[i]];
}

/// The colour of the half-line above and below each stop's dot.
List<({bool topLight, bool bottomLight})> _stubs(WidgetTester tester) => [
  for (final box in tester.widgetList<TimelineIndicatorBox>(
    find.byType(TimelineIndicatorBox),
  ))
    (
      topLight: _isLight(box.topLineColor ?? box.lineColor),
      bottomLight: _isLight(box.bottomLineColor ?? box.lineColor),
    ),
];

bool _isLight(Color color) => color.a < 0.5;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a trip seen whole is drawn in the route colour throughout', (
    tester,
  ) async {
    await _pump(tester);

    expect(_dotColors(tester), everyElement(_route));
    expect(_lineColors(tester), everyElement(_route));
  });

  testWidgets('the stops outside the stretch ridden are drawn light', (
    tester,
  ) async {
    await _pump(tester, ridden: (start: 1, end: 3));

    expect(_dotColors(tester).map(_isLight), [true, false, false, false, true]);
  });

  testWidgets('the line outside the stretch is light, and inside it is not', (
    tester,
  ) async {
    await _pump(tester, ridden: (start: 1, end: 3));

    // The line before each stop but the first: 0-1, 1-2, 2-3, 3-4.
    expect(_lineColors(tester).map(_isLight), [true, false, false, true]);
  });

  testWidgets('at the ends of the stretch each half-line follows its side', (
    tester,
  ) async {
    await _pump(tester, ridden: (start: 1, end: 3));

    final stubs = _stubs(tester);
    // The first stop has nothing above it and the last nothing below.
    expect(stubs[0].bottomLight, isTrue);
    // Boarding: light towards where the rider is not, solid towards the ride.
    expect(stubs[1].topLight, isTrue);
    expect(stubs[1].bottomLight, isFalse);
    expect(stubs[2].topLight, isFalse);
    expect(stubs[2].bottomLight, isFalse);
    // Alighting: the other way round.
    expect(stubs[3].topLight, isFalse);
    expect(stubs[3].bottomLight, isTrue);
    expect(stubs[4].topLight, isTrue);
  });

  testWidgets('a trip seen whole has no light half-lines', (tester) async {
    await _pump(tester);

    for (final stub in _stubs(tester)) {
      expect(stub.topLight, isFalse);
      expect(stub.bottomLight, isFalse);
    }
  });

  testWidgets('riding from the start leaves nothing light before it', (
    tester,
  ) async {
    await _pump(tester, ridden: (start: 0, end: 2));

    expect(_dotColors(tester).map(_isLight), [false, false, false, true, true]);
    expect(_lineColors(tester).map(_isLight), [false, false, true, true]);
  });

  testWidgets('riding to the end leaves nothing light after it', (
    tester,
  ) async {
    await _pump(tester, ridden: (start: 2, end: 4));

    expect(_dotColors(tester).map(_isLight), [true, true, false, false, false]);
    expect(_lineColors(tester).map(_isLight), [true, true, false, false]);
  });

  testWidgets('the light is lighter than a stretch already passed', (
    tester,
  ) async {
    // Half way through the trip: stops 0-2 are behind the vehicle.
    await _pump(
      tester,
      ridden: (start: 3, end: 4),
      now: _departure.add(const Duration(minutes: 25)),
    );

    final dots = _dotColors(tester);
    final passedButRidden = dots[3];
    final unridden = dots[0];
    expect(unridden.a, lessThan(passedButRidden.a));
  });

  testWidgets('the light stops keep their names readable', (tester) async {
    await _pump(tester, ridden: (start: 1, end: 3));

    for (var i = 0; i < 5; i++) {
      expect(find.text('Stop $i'), findsOneWidget);
    }
  });
}
