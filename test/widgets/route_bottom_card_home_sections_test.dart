import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/saved_trip.dart';

import '../support/bottom_card_host.dart';
import '../support/plan_fixtures.dart';

/// Literal, as a build that wrote it will have.
const String _homeSections = 'home_sections';

SavedTrip _trip() => SavedTrip.fromItinerary(
  itinerary: Itinerary.fromJson(
    planItineraryJson(departure: DateTime.utc(2026, 9, 28, 8), tripId: 't'),
  ),
  fromName: 'Home',
  toName: 'Airport',
);

const Widget _nearby = Text('nearby departures go here');

/// Pumps the card once the stored sections have been read.
Future<void> _pump(
  WidgetTester tester, {
  List<String>? sections,
  Widget? nearby = _nearby,
}) async {
  SharedPreferencesAsyncPlatform.instance = sections == null
      ? InMemorySharedPreferencesAsync.empty()
      : InMemorySharedPreferencesAsync.withData({_homeSections: sections});

  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    BottomCardHost(recentTrips: [_trip()], nearbyDepartures: nearby),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('both sections show until one is switched off', (tester) async {
    await _pump(tester);

    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.text('Nearby departures'), findsOneWidget);
    expect(find.text('nearby departures go here'), findsOneWidget);
  });

  testWidgets('recent trips can be switched off', (tester) async {
    await _pump(tester, sections: ['recentTrips:0', 'departures:1']);

    expect(find.text('Recent trips'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Nearby departures'), findsOneWidget);
  });

  testWidgets('nearby departures can be switched off', (tester) async {
    await _pump(tester, sections: ['recentTrips:1', 'departures:0']);

    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.text('Nearby departures'), findsNothing);
    expect(find.text('nearby departures go here'), findsNothing);
  });

  testWidgets('with both off there is only the search', (tester) async {
    await _pump(tester, sections: ['recentTrips:0', 'departures:0']);

    expect(find.text('Recent trips'), findsNothing);
    expect(find.text('Nearby departures'), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('they follow the order that was chosen', (tester) async {
    await _pump(tester, sections: ['departures:1', 'recentTrips:1']);

    final departuresAt = tester.getTopLeft(find.text('Nearby departures')).dy;
    final recentAt = tester.getTopLeft(find.text('Recent trips')).dy;
    expect(departuresAt, lessThan(recentAt));
  });

  testWidgets('recent trips come first by default', (tester) async {
    await _pump(tester);

    final departuresAt = tester.getTopLeft(find.text('Nearby departures')).dy;
    final recentAt = tester.getTopLeft(find.text('Recent trips')).dy;
    expect(recentAt, lessThan(departuresAt));
  });

  testWidgets('without nearby departures supplied the heading is not shown', (
    tester,
  ) async {
    await _pump(tester, nearby: null);

    expect(find.text('Nearby departures'), findsNothing);
    expect(find.text('Recent trips'), findsOneWidget);
  });
}
