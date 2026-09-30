import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/itinerary.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/screens/itinerary_detail_screen.dart';
import 'package:transportia/utils/changeover.dart';
import 'package:transportia/utils/itinerary_leg_utils.dart';
import 'package:transportia/utils/leg_notices.dart';

final DateTime _t0 = DateTime(2026, 6, 1, 10, 0);

String _at(int minutes) =>
    _t0.add(Duration(minutes: minutes)).toUtc().toIso8601String();

/// An ICE into Mannheim, a walk, and an RE out, with the ICE's platform and
/// the RE's departure time as given.
List<Leg> _change({String? iceArrivalPlatform, int reDeparts = 10}) => [
  Leg.fromJson({
    'mode': 'HIGHSPEED_RAIL',
    'startTime': _at(-40),
    'endTime': _at(0),
    'duration': 2400,
    'realTime': true,
    'from': {'name': 'Stuttgart Hbf', 'lat': 48.78, 'lon': 9.18, 'track': '8'},
    'to': {
      'name': 'Mannheim Hbf',
      'lat': 49.48,
      'lon': 8.47,
      'track': ?iceArrivalPlatform,
      'arrival': _at(0),
    },
  }),
  Leg.fromJson({
    'mode': 'WALK',
    'startTime': _at(0),
    'endTime': _at(5),
    'duration': 300,
    'from': {
      'name': 'Mannheim Hbf',
      'lat': 49.48,
      'lon': 8.47,
      'arrival': _at(0),
      'departure': _at(0),
    },
    'to': {'name': 'Mannheim Hbf', 'lat': 49.4801, 'lon': 8.4701},
  }),
  Leg.fromJson({
    'mode': 'REGIONAL_RAIL',
    'startTime': _at(reDeparts),
    'endTime': _at(reDeparts + 18),
    'duration': 1080,
    'realTime': true,
    'from': {
      'name': 'Mannheim Hbf',
      'lat': 49.4801,
      'lon': 8.4701,
      'track': '4',
      'departure': _at(reDeparts),
    },
    'to': {'name': 'Heidelberg Hbf', 'lat': 49.4, 'lon': 8.67, 'track': '2'},
  }),
];

Future<void> _pump(WidgetTester tester, List<Leg> legs) async {
  final changeover = changeoversOf(buildDisplayLegs(legs)).single;
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: TransferLegCard(
            leg: changeover.transfer,
            previousLeg: changeover.arriving,
            changeover: changeover,
            openStopSheet:
                ({
                  required String? stopId,
                  required String stopName,
                  required DateTime referenceTime,
                }) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a change with a train missing its platform says so', (
    tester,
  ) async {
    await _pump(tester, _change());
    expect(find.text(kPlatformUnknownMessage), findsOne);
  });

  testWidgets('with both platforms there is nothing to say', (tester) async {
    await _pump(tester, _change(iceArrivalPlatform: '3'));
    expect(find.text(kPlatformUnknownMessage), findsNothing);
  });

  testWidgets('a change that is missed says that instead', (tester) async {
    // Leaving before the walk is done: the platform no longer matters.
    await _pump(tester, _change(reDeparts: 2));
    expect(find.text(kMissedChangeMessage), findsOne);
    expect(find.text(kPlatformUnknownMessage), findsNothing);
  });
}
