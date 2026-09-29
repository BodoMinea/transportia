import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:transportia/models/place_details.dart';
import 'package:transportia/models/stop_time.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:transportia/widgets/map/place_details_sheet.dart';

Future<void> _pump(WidgetTester tester, Widget sheet) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Align(alignment: Alignment.bottomCenter, child: sheet),
        ),
      ),
    ),
  );
  await tester.pump();
}

PlaceDetails _rewe() => PlaceDetails.fromNominatim(
  (jsonDecode(
            File('test/fixtures/nominatim/lookup_rewe.json').readAsStringSync(),
          )
          as List)
      .single,
);

List<StopTime> _departures() => StopTimesResponse.fromJson(
  jsonDecode(File('test/fixtures/transitous/stoptimes.json').readAsStringSync())
      as Map<String, dynamic>,
).stopTimes;

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('a place', () {
    testWidgets('says what OpenStreetMap knows, and credits it', (
      tester,
    ) async {
      await _pump(
        tester,
        PlaceDetailsSheet.place(
          icon: LucideIcons.mapPin,
          title: 'REWE',
          caption: '1.3 km · Prenzlauer Berg, Berlin',
          category: 'Supermarket',
          details: _rewe(),
          confirmLabel: 'Select',
          onConfirm: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('REWE'), findsOne);
      expect(find.text('1.3 km · Prenzlauer Berg, Berlin'), findsOne);
      expect(find.text('Supermarket'), findsOne);
      expect(find.text('Schönhauser Allee 10-11, 10119 Berlin'), findsOne);
      expect(find.text('Mo–Sa 07:00–23:30'), findsOne);
      expect(find.text('+49 30 44342306'), findsOne);
      // The site's host, not the whole address of one market's page.
      expect(find.text('rewe.de'), findsOne);
      expect(find.text('Wheelchair accessible'), findsOne);
      expect(find.text('Ground floor'), findsOne);
      expect(find.text('Details © OpenStreetMap contributors'), findsOne);
    });

    testWidgets('while loading, neither facts nor credit', (tester) async {
      await _pump(
        tester,
        PlaceDetailsSheet.place(
          icon: LucideIcons.mapPin,
          title: 'REWE',
          caption: '',
          isLoading: true,
          confirmLabel: 'Select',
          onConfirm: () {},
          onCancel: () {},
        ),
      );

      expect(find.byIcon(LucideIcons.clock), findsNothing);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
    });

    testWidgets('with nothing known, just the place', (tester) async {
      await _pump(
        tester,
        PlaceDetailsSheet.place(
          icon: LucideIcons.mapPin,
          title: 'Hermannplatz',
          caption: '4.1 km · Neukölln, Berlin',
          confirmLabel: 'Select',
          onConfirm: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('Hermannplatz'), findsOne);
      expect(find.textContaining('OpenStreetMap'), findsNothing);
    });

    testWidgets('select and cancel do what they say', (tester) async {
      var confirmed = 0;
      var cancelled = 0;
      await _pump(
        tester,
        PlaceDetailsSheet.place(
          icon: LucideIcons.mapPin,
          title: 'REWE',
          caption: '',
          confirmLabel: 'Select',
          onConfirm: () => confirmed++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.text('Select'));
      await tester.tap(find.text('Cancel'));
      expect((confirmed, cancelled), (1, 1));
    });
  });

  group('a stop', () {
    testWidgets('lists its next departures and what serves it', (tester) async {
      final departures = _departures();
      await _pump(
        tester,
        PlaceDetailsSheet.stop(
          icon: LucideIcons.trainFront,
          title: 'S+U Alexanderplatz Bhf (Berlin)',
          caption: '740 m · Mitte, Berlin',
          modes: 'Suburban rail · Subway · Bus',
          departures: departures,
          confirmLabel: 'Select',
          onConfirm: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('Suburban rail · Subway · Bus'), findsOne);
      expect(find.text('NEXT DEPARTURES'), findsOne);
      expect(find.text(departures.first.headsign), findsWidgets);
    });

    testWidgets('no departures, no heading', (tester) async {
      await _pump(
        tester,
        PlaceDetailsSheet.stop(
          icon: LucideIcons.trainFront,
          title: 'Somewhere',
          caption: '',
          departures: const [],
          confirmLabel: 'Select',
          onConfirm: () {},
          onCancel: () {},
        ),
      );

      expect(find.text('NEXT DEPARTURES'), findsNothing);
    });
  });

  group('a point', () {
    testWidgets('cannot be taken before it has a name', (tester) async {
      var confirmed = 0;
      await _pump(
        tester,
        PlaceDetailsSheet.point(
          title: '',
          isLoading: true,
          confirmLabel: 'Select',
          onConfirm: () => confirmed++,
          onCancel: () {},
        ),
      );

      await tester.tap(find.text('Select'));
      expect(confirmed, 0);
      expect(find.text('Point on the map'), findsOne);
    });

    testWidgets('named, it can', (tester) async {
      var confirmed = 0;
      await _pump(
        tester,
        PlaceDetailsSheet.point(
          title: 'Grunerstraße 20',
          caption: '1.0 km',
          confirmLabel: 'Select',
          onConfirm: () => confirmed++,
          onCancel: () {},
        ),
      );

      await tester.tap(find.text('Select'));
      expect(confirmed, 1);
      expect(find.text('Grunerstraße 20'), findsOne);
    });
  });
}
