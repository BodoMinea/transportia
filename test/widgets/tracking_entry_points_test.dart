import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/models/stop_time.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/itinerary_detail_screen.dart';
import 'package:transportia/widgets/track_departure_button.dart';

import '../support/plan_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(900, 1600)),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the itinerary screen', () {
    Itinerary journey(Duration fromNow) => Itinerary.fromJson(
      planItineraryJson(departure: DateTime.now().add(fromNow)),
    );

    testWidgets('offers to track a trip that is still ahead', (tester) async {
      await _pump(
        tester,
        JourneyOverviewWidget(itinerary: journey(const Duration(hours: 1))),
      );

      expect(find.bySemanticsLabel('Track this trip'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Show the whole journey on the map'),
        findsOneWidget,
      );
    });

    testWidgets('does not offer it for a trip that is over', (tester) async {
      await _pump(
        tester,
        JourneyOverviewWidget(itinerary: journey(const Duration(hours: -5))),
      );

      expect(find.bySemanticsLabel('Track this trip'), findsNothing);
      expect(
        find.bySemanticsLabel('Show the whole journey on the map'),
        findsOneWidget,
      );
    });
  });

  group('a departure', () {
    final stopTime = StopTimesResponse.fromJson(
      jsonDecode(
            File('test/fixtures/transitous/stoptimes.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    ).stopTimes.first;

    testWidgets('can be tracked, and says which one', (tester) async {
      await _pump(tester, TrackDepartureButton(stopTime: stopTime));

      expect(
        find.bySemanticsLabel(
          'Track ${stopTime.displayName} to ${stopTime.headsign}',
        ),
        findsOneWidget,
      );
    });
  });
}
