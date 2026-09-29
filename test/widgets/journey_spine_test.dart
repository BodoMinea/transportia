import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/models/routing_options.dart';
import 'package:transportia/models/transit_mode_group.dart';
import 'package:transportia/models/transitous/enums.dart';
import 'package:transportia/models/transitous/server_config.dart';
import 'package:transportia/widgets/options/icon_controls.dart';
import 'package:transportia/theme/journey_metrics.dart';
import 'package:transportia/widgets/journey/spine_node.dart';
import 'package:transportia/widgets/journey/spine_row.dart';
import 'package:transportia/widgets/search/journey_segment.dart';
import 'package:transportia/widgets/search/journey_spine.dart';
import 'package:transportia/widgets/search/traveller_strip.dart';
import 'package:transportia/widgets/search/street_leg_section.dart';

/// Holds the options the way the search screen will, so a tap on a control
/// comes back as a rebuilt spine rather than only as a callback.
class _Host extends StatefulWidget {
  const _Host({required this.initial});

  final RoutingOptions initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RoutingOptions options = widget.initial;
  int viaTaps = 0;
  bool limitToMyProviders = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 380,
            child: JourneySpine(
              options: options,
              capabilities: ServerConfig.fallback,
              onChanged: (next) => setState(() => options = next),
              onAddViaStop: () => viaTaps++,
              limitToMyProviders: limitToMyProviders,
              hasRentalProviders: false,
              onLimitToMyProvidersChanged: (value) =>
                  setState(() => limitToMyProviders = value),
            ),
          ),
        ),
      ),
    );
  }
}

Future<_HostState> _pumpSpine(
  WidgetTester tester, {
  RoutingOptions initial = RoutingOptions.defaults,
}) async {
  // Tall enough that an expanded stage is on screen and so tappable; the
  // default 800x600 surface would push the last stage past the bottom.
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_Host(initial: initial));
  return tester.state<_HostState>(find.byType(_Host));
}

/// An icon-only pick that is actually on screen.
///
/// `AnimatedCrossFade` keeps the collapsed branch in the tree behind an
/// `IgnorePointer`, so "is it offered" has to mean "can it be pressed".
Finder _pick(String label) => find
    .byWidgetPredicate((w) => w is IconPick && w.label == label)
    .hitTestable();

Finder _valueChip(String label) => find
    .byWidgetPredicate((w) => w is ValueChip && w.label == label)
    .hitTestable();

Finder _modeChip(String label) => find
    .byWidgetPredicate((w) => w is ModeChip && w.label == label)
    .hitTestable();

Future<void> _open(WidgetTester tester, String headline) async {
  await tester.tap(find.text(headline));
  await tester.pumpAndSettle();
}

/// Lets an on-screen message time out, so it does not outlive the test.
Future<void> _quiet(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));

void main() {
  testWidgets('collapsed sections summarise the current state', (tester) async {
    await _pumpSpine(tester);

    expect(find.text('TO THE STATION'), findsOneWidget);
    expect(find.text('PUBLIC TRANSPORT'), findsOneWidget);
    expect(find.text('FROM THE STATION'), findsOneWidget);

    // Both street legs default to a quarter-hour walk.
    expect(find.text('Walk · 15 min'), findsNWidgets(2));
    expect(find.text('All transport · unlimited changes'), findsOneWidget);
  });

  testWidgets('the summary follows a mile mode without expanding it', (
    tester,
  ) async {
    await _pumpSpine(
      tester,
      initial: RoutingOptions.defaults.copyWith(
        firstMileModes: const [TransitMode.bike],
        maxFirstMileTime: const Duration(minutes: 90),
      ),
    );

    expect(find.text('Bike · 1 h 30'), findsOneWidget);
    expect(find.text('Walk · 15 min'), findsOneWidget);
  });

  testWidgets('opening one stage leaves the others closed', (tester) async {
    await _pumpSpine(tester);
    expect(_pick('Rental'), findsNothing);

    await _open(tester, 'TO THE STATION');
    // One street leg is open, so each mile mode is offered exactly once.
    expect(_pick('Rental'), findsOneWidget);
    expect(_pick('Park & ride'), findsOneWidget);
    expect(_pick('No reservation needed'), findsNothing);

    await _open(tester, 'PUBLIC TRANSPORT');
    // Stages expand independently, so both stay open.
    expect(_pick('Rental'), findsOneWidget);
    expect(_pick('No reservation needed'), findsOneWidget);

    await _open(tester, 'TO THE STATION');
    expect(_pick('Rental'), findsNothing);
    expect(_pick('No reservation needed'), findsOneWidget);
  });

  testWidgets('a mile mode announces itself, since the icon cannot', (
    tester,
  ) async {
    final host = await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    await tester.tap(_pick('Rental'));
    await tester.pump();

    expect(host.options.firstMileModes, contains(TransitMode.rental));
    expect(find.text('Rental to the station'), findsOneWidget);

    // And it clears itself rather than sitting over the card.
    await _quiet(tester);
    expect(find.text('Rental to the station'), findsNothing);
  });

  testWidgets('every street mode is reachable, by icon or by chevron', (
    tester,
  ) async {
    // A mode the defaults editor can store but this row cannot show would
    // light up nothing and be summarised as walking.
    await _pumpSpine(
      tester,
      initial: RoutingOptions.defaults.copyWith(
        firstMileModes: const [TransitMode.car],
      ),
    );
    expect(find.text('Car · 15 min'), findsOneWidget);

    await _open(tester, 'TO THE STATION');
    for (final mode in mileModeChoices.keys) {
      expect(
        _pick(mileModeLabel(mode)),
        findsOneWidget,
        reason: '${mode.wireName} has no icon',
      );
    }
    // Drop-off is no longer one of the icons.
    expect(_pick('Drop-off'), findsNothing);

    await tester.tap(_pick('More ways to travel'));
    await tester.pumpAndSettle();
    for (final mode in mileModeExtras.keys) {
      expect(
        find.text(mileModeLabel(mode)).hitTestable(),
        findsOneWidget,
        reason: '${mode.wireName} is not behind the chevron',
      );
    }
    expect({
      ...mileModeChoices.keys,
      ...mileModeExtras.keys,
    }, RoutingOptions.streetModeChoices.toSet());
  });

  testWidgets('a mode from the chevron comes back as a chip', (tester) async {
    final host = await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    await tester.tap(_pick('More ways to travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drop-off').hitTestable());
    await tester.pump();

    expect(host.options.firstMileModes, contains(TransitMode.carDropoff));
    expect(_modeChip('Drop-off'), findsOneWidget);
    expect(find.text('Walk, Drop-off · 15 min'), findsOneWidget);

    await tester.tap(_modeChip('Drop-off'));
    await tester.pump();
    expect(
      host.options.firstMileModes,
      isNot(contains(TransitMode.carDropoff)),
    );
    await _quiet(tester);
  });

  testWidgets('picking a shared vehicle brings rentals with it', (
    tester,
  ) async {
    // Filtering shared vehicles says nothing unless rentals are in play.
    final host = await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    await tester.tap(_pick('More ways to travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared cargo bike').hitTestable());
    await tester.pump();

    expect(
      host.options.firstMileRentalFormFactors,
      contains(RentalFormFactor.cargoBicycle),
    );
    expect(host.options.firstMileModes, contains(TransitMode.rental));

    // And it stays this mile's business. One list held for both meant a
    // cargo bike to the station asked for one on the way back as well.
    expect(host.options.lastMileRentalFormFactors, isEmpty);
    expect(host.options.lastMileModes, isNot(contains(TransitMode.rental)));
    await _quiet(tester);
  });

  group('the rental icon', () {
    /// Whether the icon reads as lit, which is what the rider goes by.
    bool selected(WidgetTester tester) =>
        tester.widget<IconPick>(_pick('Rental')).selected;

    testWidgets('ticks the vehicles it stands for', (tester) async {
      // It used to toggle the mode and nothing else, so the expanded list
      // looked identical before and after.
      final host = await _pumpSpine(tester);
      await _open(tester, 'TO THE STATION');

      await tester.tap(_pick('Rental'));
      await tester.pump();

      expect(host.options.firstMileRentalFormFactors, kRentalIconFactors);
      expect(host.options.firstMileModes, contains(TransitMode.rental));
      expect(selected(tester), isTrue);
      await _quiet(tester);
    });

    testWidgets('turning it off leaves a separate pick alone', (tester) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileModes: const [TransitMode.walk, TransitMode.rental],
          firstMileRentalFormFactors: const [
            RentalFormFactor.bicycle,
            RentalFormFactor.car,
            RentalFormFactor.scooterStanding,
            RentalFormFactor.other,
          ],
        ),
      );
      await _open(tester, 'TO THE STATION');
      expect(selected(tester), isTrue);

      await tester.tap(_pick('Rental'));
      await tester.pump();

      // Only its own three go. A shared car was asked for by name and is
      // still shown by name, so it survives.
      expect(host.options.firstMileRentalFormFactors, [RentalFormFactor.car]);
      expect(host.options.firstMileModes, contains(TransitMode.rental));
      expect(selected(tester), isFalse);
      expect(_modeChip('Shared car'), findsOneWidget);
      await _quiet(tester);
    });

    testWidgets('dropping the last vehicle drops rentals', (tester) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileModes: const [TransitMode.walk, TransitMode.rental],
          firstMileRentalFormFactors: kRentalIconFactors,
        ),
      );
      await _open(tester, 'TO THE STATION');

      await tester.tap(_pick('Rental'));
      await tester.pump();

      // Rentals lit over a mile with nothing to rent is the state that
      // started this. No control may reach it.
      expect(host.options.firstMileRentalFormFactors, isEmpty);
      expect(host.options.firstMileModes, isNot(contains(TransitMode.rental)));
      await _quiet(tester);
    });

    testWidgets('says its vehicles once, not twice', (tester) async {
      await _pumpSpine(tester);
      await _open(tester, 'TO THE STATION');

      await tester.tap(_pick('Rental'));
      await tester.pump();

      // Chips carry what the icons cannot say, so a lit icon's own three
      // have no business appearing beside it as well.
      for (final factor in kRentalIconFactors) {
        expect(
          _modeChip(rentalFormFactorLabels[factor]!),
          findsNothing,
          reason: '${factor.wireName} is reported twice',
        );
      }
      await _quiet(tester);
    });

    testWidgets('one vehicle of its own is not enough to light it', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'TO THE STATION');

      await tester.tap(_pick('More ways to travel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared bike').hitTestable());
      await tester.pump();

      // Rentals are on, but not the set the icon stands for — so the icon
      // stays dark and the bike says itself.
      expect(host.options.firstMileModes, contains(TransitMode.rental));
      expect(selected(tester), isFalse);
      expect(_modeChip('Shared bike'), findsOneWidget);
      await _quiet(tester);
    });
  });

  testWidgets('the stage icon follows the last mode picked, left to right', (
    tester,
  ) async {
    // Which mode was chosen first should not decide the icon forever.
    await _pumpSpine(
      tester,
      initial: RoutingOptions.defaults.copyWith(
        firstMileModes: const [TransitMode.walk, TransitMode.bike],
      ),
    );

    expect(find.text('Walk, Bike · 15 min'), findsOneWidget);
    expect(
      mileModesIcon(const [TransitMode.walk, TransitMode.bike]),
      mileModeIcon(TransitMode.bike),
    );
  });

  group('transport', () {
    testWidgets('"All transport" holds only while nothing is narrowed', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('Boat'));
      await tester.pump();

      expect(find.text('All transport · unlimited changes'), findsNothing);
      expect(host.options.transitModes, isNotEmpty);
      expect(host.options.transitModes, isNot(contains(TransitMode.ferry)));

      await tester.tap(_pick('Boat'));
      await tester.pump();

      expect(find.text('All transport · unlimited changes'), findsOneWidget);
      // Everything on sends nothing, so a mode added upstream is not
      // silently excluded by an enumerated list.
      expect(host.options.transitModes, isEmpty);
      await _quiet(tester);
    });

    testWidgets('everything on needs no chips at all', (tester) async {
      await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      // Four lit icons and "All transport" already say it; a chip per mode
      // would be twenty chips saying nothing.
      expect(find.byType(ModeChip), findsNothing);
    });

    testWidgets('unticking a mode from the dropdown narrows the search', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('More transport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flights').hitTestable());
      await tester.pump();

      // Flights were on, because an absent transitModes means every mode.
      expect(host.options.transitModes, isNotEmpty);
      expect(host.options.transitModes, isNot(contains(TransitMode.airplane)));
      expect(find.text('All transport · unlimited changes'), findsNothing);
      await _quiet(tester);
    });

    testWidgets('the row names a mode the four icons cannot show', (
      tester,
    ) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.withTransitSelection(
          TransitSelection({
            ...TransitModeGroup.rail.modes,
            TransitMode.airplane,
          }),
        ),
      );
      await _open(tester, 'PUBLIC TRANSPORT');

      // Rail is lit; nothing on screen otherwise says flights are in.
      expect(_modeChip('Flights'), findsOneWidget);
      expect(find.text('Rail, Flights · unlimited changes'), findsOneWidget);

      await tester.tap(_modeChip('Flights'));
      await tester.pump();

      expect(host.options.transitModes, isNot(contains(TransitMode.airplane)));
      expect(_modeChip('Flights'), findsNothing);
      await _quiet(tester);
    });

    testWidgets('a half-picked group is marked as such', (tester) async {
      await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.withTransitSelection(
          TransitSelection({TransitMode.longDistance}),
        ),
      );
      await _open(tester, 'PUBLIC TRANSPORT');

      final rail = tester.widget<IconPick>(
        find.byWidgetPredicate((w) => w is IconPick && w.label == 'Rail'),
      );
      expect(rail.selected, isFalse);
      expect(rail.subdued, isTrue, reason: 'a partial group should say so');
      expect(_modeChip('Intercity rail'), findsOneWidget);
    });

    testWidgets('the transfer limit reads as a number then as unlimited', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_valueChip('Maximum changes'));
      await tester.pumpAndSettle();

      final slider = tester.widget<OptionSlider>(find.byType(OptionSlider));
      expect(slider.max, RoutingOptions.unlimitedTransfersSliderValue);

      slider.onChanged(2);
      await tester.pump();
      expect(host.options.maxTransfers, 2);
      expect(find.text('All transport · max 2 changes'), findsOneWidget);

      slider.onChanged(RoutingOptions.unlimitedTransfersSliderValue.toDouble());
      await tester.pump();
      // Unlimited omits the parameter rather than sending a large number.
      expect(host.options.maxTransfers, isNull);
      expect(find.text('All transport · unlimited changes'), findsOneWidget);
      await _quiet(tester);
    });
  });

  group('bike carriage', () {
    testWidgets('is always offered, and comes on with a bike at both ends', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');
      // Offered from the start, so asking for a service that carries bikes is
      // possible whatever the street legs say.
      expect(_pick('Bike not carried'), findsOneWidget);

      await _open(tester, 'TO THE STATION');
      await tester.tap(_pick('Bike'));
      await tester.pumpAndSettle();
      // One end is not enough: the bike is being left at the station.
      expect(_pick('Bike not carried'), findsOneWidget);

      await _open(tester, 'FROM THE STATION');
      await tester.tap(_pick('Bike').last);
      await tester.pumpAndSettle();

      expect(_pick('Bike carried on board'), findsOneWidget);
      expect(host.options.requireBikeTransport, isTrue);
      expect(host.options.bikeCarriageIsManual, isFalse);
      await _quiet(tester);
    });

    testWidgets('can be asked for without a bike at both ends', (tester) async {
      final host = await _pumpSpine(tester);
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('Bike not carried'));
      await tester.pump();

      expect(host.options.bikeAtBothEnds, isFalse);
      expect(host.options.requireBikeTransport, isTrue);
      await _quiet(tester);
    });

    testWidgets('stays the rider\'s to turn off', (tester) async {
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileModes: const [TransitMode.bike],
          lastMileModes: const [TransitMode.bike],
        ),
      );
      await _open(tester, 'PUBLIC TRANSPORT');

      await tester.tap(_pick('Bike carried on board'));
      await tester.pump();

      expect(host.options.requireBikeTransport, isFalse);
      expect(host.options.bikeCarriageIsManual, isTrue);
      expect(find.text('Bike not carried'), findsOneWidget);
      expect(_pick('Bike not carried'), findsOneWidget);
      await _quiet(tester);
    });

    testWidgets('outlives a change of mile mode', (tester) async {
      // The icon no longer comes and goes with the street legs, so the
      // decision has somewhere to live and something on screen to undo it.
      final host = await _pumpSpine(
        tester,
        initial: RoutingOptions.defaults.copyWith(
          firstMileModes: const [TransitMode.bike],
          lastMileModes: const [TransitMode.bike],
          bikeCarriageOverride: false,
        ),
      );
      await _open(tester, 'FROM THE STATION');
      await tester.tap(_pick('Bike'));
      await tester.pumpAndSettle();

      expect(host.options.bikeCarriageIsManual, isTrue);
      expect(host.options.requireBikeTransport, isFalse);

      await _open(tester, 'PUBLIC TRANSPORT');
      expect(_pick('Bike not carried'), findsOneWidget);
      await _quiet(tester);
    });
  });

  group('traveller', () {
    testWidgets('step-free keeps its name and says what it did', (
      tester,
    ) async {
      final host = await _pumpSpine(tester);

      expect(find.text('Step-free'), findsOneWidget);
      await tester.tap(find.text('Step-free'));
      await tester.pump();

      expect(host.options.wheelchairAccessibleOnly, isTrue);
      expect(find.text('Step-free only'), findsOneWidget);
      await _quiet(tester);
    });

    testWidgets('pace hides its sliders until asked, cycling until it cycles', (
      tester,
    ) async {
      await _pumpSpine(tester);
      expect(find.text('Walking'), findsNothing);

      await tester.tap(_pick('Pace'));
      await tester.pumpAndSettle();

      expect(find.text('Walking'), findsOneWidget);
      // Nothing in the journey cycles yet, so no cycling speed applies.
      expect(find.text('Cycling'), findsNothing);

      await _open(tester, 'TO THE STATION');
      await tester.tap(_pick('Bike'));
      await tester.pumpAndSettle();

      expect(find.text('Cycling'), findsOneWidget);
      await _quiet(tester);
    });
  });

  testWidgets('the via picker is left to the screen that owns the search', (
    tester,
  ) async {
    final host = await _pumpSpine(tester);
    await _open(tester, 'PUBLIC TRANSPORT');

    await tester.tap(_pick('Travel through a stop'));
    await tester.pump();

    expect(host.viaTaps, 1);
  });

  testWidgets('a tooltip does not outlive the layout it pointed at', (
    tester,
  ) async {
    await _pumpSpine(tester);
    await _open(tester, 'TO THE STATION');

    // Held rather than tester.longPress, which lifts the finger and so
    // dismisses the tooltip on its way out.
    final held = await tester.startGesture(tester.getCenter(_pick('Rental')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // The picks carry no text of their own, so this is the bubble.
    expect(find.text('Rental'), findsOneWidget);

    // Picking a mode moves the row out from under the finger, so no exit
    // gesture ever fires and the bubble would otherwise strand itself.
    await tester.tap(_pick('Bike'));
    await tester.pump();
    expect(find.text('Rental'), findsNothing);

    await held.up();
    await _quiet(tester);
  });

  test('every mode the dropdown offers has a name', () {
    for (final mode in TransitModeGroup.allSelectable) {
      expect(TransitModeGroup.modeLabel(mode), isNotEmpty);
    }
  });

  group('the stages read as one line', () {
    testWidgets('every stage puts its node on the same centre', (tester) async {
      // The rings and the two endpoint markers share one gutter, which is what
      // makes the card the top and bottom of a single drawing.
      await _pumpSpine(tester);

      final centres = {
        for (final node in find.byType(SpineNode).evaluate())
          tester.getRect(find.byWidget(node.widget)).center.dx.roundToDouble(),
      };
      expect(centres, hasLength(1));
    });

    testWidgets('the three stages leave no gap for the line to fall down', (
      tester,
    ) async {
      // Each row paints its own stretch, so a gap between rows is a gap in the
      // line. The rows have to touch.
      await _pumpSpine(tester);

      final rects = find
          .byType(JourneySegment)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList();

      expect(rects, hasLength(3));
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, closeTo(rects[i - 1].bottom, 0.5));
      }
    });

    testWidgets('a street stage is dotted and a ride is not', (tester) async {
      await _pumpSpine(tester);

      final stages = find
          .byType(JourneySegment)
          .evaluate()
          .map((e) => e.widget as JourneySegment)
          .toList();

      expect(stages[0].dashed, isTrue);
      expect(stages[1].dashed, isFalse);
      expect(stages[2].dashed, isTrue);
    });

    testWidgets('a ring is wide enough to hold its glyph', (tester) async {
      await _pumpSpine(tester);

      final ring = tester.getRect(find.byType(SpineNode).first);
      expect(ring.width, JourneyMetrics.ring);
      expect(ring.height, JourneyMetrics.ring);
    });
  });

  group('a stage answers to the whole row', () {
    testWidgets('a tap well clear of the title still opens it', (tester) async {
      // The hit area used to be the width of the two lines of text, so most
      // of a row looked pressable and did nothing.
      await _pumpSpine(tester);
      expect(_pick('Bike'), findsNothing);

      final row = tester.getRect(find.byType(JourneySegment).first);
      // Right-hand end of the row, past where any of the text reaches.
      await tester.tapAt(Offset(row.right - 30, row.top + 12));
      await tester.pumpAndSettle();

      expect(_pick('Bike'), findsOneWidget);
    });

    testWidgets('the ring opens it too', (tester) async {
      await _pumpSpine(tester);
      await tester.tap(find.byType(SpineNode).first);
      await tester.pumpAndSettle();

      expect(_pick('Bike'), findsOneWidget);
    });

    testWidgets('a miss inside the controls does not fold it away', (
      tester,
    ) async {
      await _pumpSpine(tester);
      await tester.tap(find.byType(SpineNode).first);
      await tester.pumpAndSettle();
      expect(_pick('Bike'), findsOneWidget);

      // Just under the row of icon controls: inside the expanded area, on no
      // control in particular.
      final walk = tester.getRect(_pick('Walk'));
      await tester.tapAt(Offset(walk.right + 4, walk.center.dy));
      await tester.pumpAndSettle();

      expect(_pick('Bike'), findsOneWidget);
    });
  });

  group('the card has one text edge', () {
    testWidgets('the traveller controls start where a stage summary does', (
      tester,
    ) async {
      // Three edges before this: the strip at the card's own left, the fields
      // at the gutter, the stages a gap further in.
      await _pumpSpine(tester);

      // The strip's own leading edge, not its chip's label, which sits
      // inside that chip's icon and padding.
      final strip = tester.getRect(find.byType(TravellerStrip));
      final summary = tester.getRect(find.text('Walk · 15 min').first);
      expect(strip.left, closeTo(summary.left, 0.5));
    });

    testWidgets('the line runs unbroken past the traveller strip', (
      tester,
    ) async {
      // The dotted rail from the origin used to stop short of the first
      // stage's ring by the height of this strip.
      await _pumpSpine(tester);

      final rows =
          find
              .byType(SpineRow)
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget)))
              .toList()
            ..sort((a, b) => a.top.compareTo(b.top));

      expect(rows.length, greaterThanOrEqualTo(4));
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].top, closeTo(rows[i - 1].bottom, 0.5));
      }
    });
  });
}
