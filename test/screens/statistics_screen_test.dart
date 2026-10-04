import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/statistics_screen.dart';
import 'package:transportia/services/saved_trips_service.dart';

import '../support/plan_fixtures.dart';

final DateTime _now = DateTime.utc(2026, 9, 28, 12);

SavedTrip _trip({
  required int hoursFromNow,
  required String from,
  required String to,
}) => SavedTrip.fromItinerary(
  itinerary: Itinerary.fromJson(
    planItineraryJson(
      departure: _now.add(Duration(hours: hoursFromNow)),
      tripId: 'trip-$hoursFromNow',
    ),
  ),
  fromName: from,
  toName: to,
);

/// Opens the screen on [trips], stored the way the saved trips tab keeps them.
Future<void> _pump(WidgetTester tester, List<SavedTrip> trips) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    for (final trip in trips) {
      await SavedTripsService.saveTrip(trip);
    }
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 2400)),
          child: StatisticsScreen(clock: () => _now),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SavedTripsService.savedTripsListenable.value = const [];
  });

  testWidgets('asks for some saved trips when there are none', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Your Travel Stats'), findsOneWidget);
    expect(find.textContaining('Save a few trips'), findsOneWidget);
    expect(find.text('Time Spent (past trips)'), findsNothing);
  });

  testWidgets('counts past and upcoming trips', (tester) async {
    await _pump(tester, [
      _trip(hoursFromNow: -6, from: 'Home', to: 'Work'),
      _trip(hoursFromNow: -3, from: 'Home', to: 'Work'),
      _trip(hoursFromNow: 5, from: 'Home', to: 'Gym'),
    ]);

    // Each count sits in the tile its label names.
    Finder tileOf(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;

    expect(
      find.descendant(of: tileOf('Past'), matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tileOf('Upcoming'), matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('shows what the past trips came to', (tester) async {
    await _pump(tester, [
      _trip(hoursFromNow: -6, from: 'Home', to: 'Work'),
      _trip(hoursFromNow: -3, from: 'Home', to: 'Gym'),
    ]);

    expect(find.text('Time Spent (past trips)'), findsOneWidget);
    // 2 x 8 minutes on foot, 2 x 15 on the train.
    expect(find.text('16m'), findsWidgets);
    expect(find.text('30m'), findsWidgets);
    expect(find.text('Mode Share'), findsOneWidget);
    expect(find.text('Top Places'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('leaves out the breakdowns when every trip is still ahead', (
    tester,
  ) async {
    await _pump(tester, [_trip(hoursFromNow: 5, from: 'Home', to: 'Gym')]);

    expect(find.text('Time Spent (past trips)'), findsNothing);
    expect(find.textContaining('Save a few trips'), findsOneWidget);
  });
}
