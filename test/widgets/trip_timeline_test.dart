import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/journey_stop.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/utils/vehicle_position.dart';
import 'package:transportia/widgets/journey/trip_timeline.dart';

/// The stop timeline shared by Connection Info and the map's trip focus card:
/// every stop of one trip, with the vehicle drawn where it currently is.
final DateTime _departure = DateTime.utc(2026, 6, 1, 10);

DateTime _at(Duration offset) => _departure.add(offset);

JourneyStop _stop({
  required String name,
  DateTime? arrival,
  DateTime? departure,
  String? track,
  bool cancelled = false,
}) => JourneyStop(
  name: name,
  stopId: 'stop-$name',
  lat: 0,
  lon: 0,
  arrival: arrival,
  departure: departure,
  scheduledArrival: arrival,
  scheduledDeparture: departure,
  track: track,
  scheduledTrack: track,
  cancelled: cancelled,
  alerts: const [],
);

final List<JourneyStop> _stops = [
  _stop(name: 'Origin', departure: _departure, track: '3'),
  _stop(
    name: 'Middle',
    arrival: _at(const Duration(minutes: 10)),
    departure: _at(const Duration(minutes: 12)),
  ),
  _stop(name: 'Terminus', arrival: _at(const Duration(minutes: 20))),
];

Future<List<String>> _pumpAt(
  WidgetTester tester,
  DateTime now, {
  List<JourneyStop>? stops,
  void Function(String? stopId)? onTap,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final timelineStops = stops ?? _stops;
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
              stops: timelineStops,
              position: estimateVehiclePosition(timelineStops, now: now),
              routeColor: const Color(0xFF1E88E5),
              routeTextColor: const Color(0xFFFFFFFF),
              modeIcon: LucideIcons.trainFront,
              isLive: true,
              onStopTap:
                  ({
                    required String? stopId,
                    required String stopName,
                    required DateTime referenceTime,
                  }) => onTap?.call(stopId),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return timelineStops.map((s) => s.name).toList();
}

/// How many vehicle icons the timeline is drawing.
int _vehicleMarkers(WidgetTester tester) =>
    tester.widgetList(find.byIcon(LucideIcons.trainFront)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('every stop is named, in the order they are called at', (
    tester,
  ) async {
    await _pumpAt(tester, _departure);

    for (final name in ['Origin', 'Middle', 'Terminus']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('Origin')).dy,
      lessThan(tester.getTopLeft(find.text('Terminus')).dy),
    );
  });

  testWidgets('the vehicle is drawn exactly once, wherever it is', (
    tester,
  ) async {
    // Before departure, running between stops, dwelling, and after arrival —
    // splicing a marker in and also marking a stop would show two vehicles.
    for (final now in [
      _at(const Duration(minutes: -5)),
      _at(const Duration(minutes: 5)),
      _at(const Duration(minutes: 11)),
      _at(const Duration(hours: 2)),
    ]) {
      await _pumpAt(tester, now);
      expect(_vehicleMarkers(tester), 1, reason: 'at $now');
    }
  });

  testWidgets('the next stop is badged as upcoming, and only that one', (
    tester,
  ) async {
    await _pumpAt(tester, _at(const Duration(minutes: 5)));
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('nothing is upcoming once the trip is over', (tester) async {
    await _pumpAt(tester, _at(const Duration(hours: 2)));
    expect(find.text('Upcoming'), findsNothing);
  });

  testWidgets('a stop prints its track and its cancellation', (tester) async {
    await _pumpAt(
      tester,
      _departure,
      stops: [
        _stop(name: 'Origin', departure: _departure, track: '3'),
        _stop(
          name: 'Middle',
          arrival: _at(const Duration(minutes: 10)),
          departure: _at(const Duration(minutes: 12)),
          cancelled: true,
        ),
        _stop(name: 'Terminus', arrival: _at(const Duration(minutes: 20))),
      ],
    );

    expect(find.text('Track 3'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  testWidgets('tapping a stop asks for that stop', (tester) async {
    String? tapped;
    await _pumpAt(tester, _departure, onTap: (stopId) => tapped = stopId);

    await tester.tap(find.text('Middle'));
    expect(tapped, 'stop-Middle');
  });

  testWidgets('a stop with no id is not offered as a tap', (tester) async {
    var tapped = false;
    final anonymous = [
      JourneyStop(
        name: 'Nowhere',
        stopId: null,
        lat: 0,
        lon: 0,
        arrival: null,
        departure: _departure,
        scheduledArrival: null,
        scheduledDeparture: _departure,
        track: null,
        scheduledTrack: null,
        cancelled: false,
        alerts: const [],
      ),
      _stop(name: 'Terminus', arrival: _at(const Duration(minutes: 20))),
    ];

    await _pumpAt(
      tester,
      _departure,
      stops: anonymous,
      onTap: (_) => tapped = true,
    );

    await tester.tap(find.text('Nowhere'));
    expect(tapped, isFalse);
  });
}
