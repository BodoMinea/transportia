import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/transit_mode_group.dart';
import '../models/transitous/enums.dart';
import 'leg_helper.dart';

/// Which modes name a stop, strongest first, each shown with the leg icon of
/// the mode it is keyed by.
///
/// A stop is called after the biggest thing that calls at it: Alexanderplatz
/// is a railway station that also has buses, not a bus stop with trains. An
/// S-Bahn station counts as a railway station, which is why rail is keyed by
/// [TransitMode.rail] rather than borrowing the suburban leg's tram.
final List<(TransitMode, Set<TransitMode>)> _kStopModeRanking = [
  (TransitMode.airplane, {TransitMode.airplane}),
  (TransitMode.rail, {TransitMode.rail, ...TransitModeGroup.rail.modes}),
  (TransitMode.subway, {TransitMode.subway}),
  (TransitMode.tram, {TransitMode.tram}),
  (TransitMode.ferry, {TransitMode.ferry}),
  (TransitMode.aerialLift, {TransitMode.aerialLift, TransitMode.funicular}),
  (TransitMode.bus, {TransitMode.bus}),
  (TransitMode.coach, {TransitMode.coach}),
];

/// A stop nothing is known to serve: one remembered before modes were, or
/// one served only by modes too vague to draw (on demand, flexible).
const IconData kUnknownStopIcon = LucideIcons.signpost;

/// The icon for a stop served by [modes].
IconData stopIcon(Iterable<TransitMode> modes) {
  final served = {for (final mode in modes) TransitModeGroup.canonical(mode)};
  for (final (shownAs, ranked) in _kStopModeRanking) {
    if (served.any(ranked.contains)) return getLegIcon(shownAs.wireName);
  }
  return kUnknownStopIcon;
}

/// The icon for a place of the geocoder's [type]; a stop is drawn by what
/// serves it.
IconData placeIcon(String type, {Iterable<TransitMode> modes = const []}) =>
    switch (type.toUpperCase()) {
      'STOP' => stopIcon(modes),
      'ADDRESS' => LucideIcons.locateFixed,
      _ => LucideIcons.mapPin,
    };
