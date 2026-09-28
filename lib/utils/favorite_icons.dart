import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/transitous/enums.dart';
import 'place_icons.dart';

class FavoriteIconOption {
  const FavoriteIconOption(this.name, this.icon);

  final String name;
  final IconData icon;
}

const List<FavoriteIconOption> favoriteIconOptions = [
  FavoriteIconOption('mapPin', LucideIcons.mapPin),
  FavoriteIconOption('home', LucideIcons.house),
  FavoriteIconOption('briefcase', LucideIcons.briefcase),
  FavoriteIconOption('school', LucideIcons.school),
  FavoriteIconOption('shoppingBag', LucideIcons.shoppingBag),
  FavoriteIconOption('coffee', LucideIcons.coffee),
  FavoriteIconOption('utensils', LucideIcons.utensils),
  FavoriteIconOption('dumbbell', LucideIcons.dumbbell),
  FavoriteIconOption('heart', LucideIcons.heart),
  FavoriteIconOption('star', LucideIcons.star),
  FavoriteIconOption('music', LucideIcons.music),
  FavoriteIconOption('plane', LucideIcons.plane),
];

/// Every icon a favourite can carry: the options above, and what a stop is
/// drawn as in the lists, which a stop is kept with when it is hearted. Those
/// are not offered in the picker, whose grid does not scroll and would not
/// fit them on a small phone; picking another icon replaces one.
const Map<String, IconData> _favoriteIconMap = {
  'mapPin': LucideIcons.mapPin,
  'home': LucideIcons.house,
  'briefcase': LucideIcons.briefcase,
  'school': LucideIcons.school,
  'shoppingBag': LucideIcons.shoppingBag,
  'coffee': LucideIcons.coffee,
  'utensils': LucideIcons.utensils,
  'dumbbell': LucideIcons.dumbbell,
  'heart': LucideIcons.heart,
  'star': LucideIcons.star,
  'music': LucideIcons.music,
  'plane': LucideIcons.plane,
  'train': LucideIcons.trainFront,
  'subway': LucideIcons.squareArrowDown,
  'tram': LucideIcons.tramFront,
  'ferry': LucideIcons.ship,
  'cableCar': LucideIcons.cableCar,
  'bus': LucideIcons.busFront,
  'coach': LucideIcons.bus,
  'stop': kUnknownStopIcon,
};

IconData iconForFavorite(String iconName) {
  return _favoriteIconMap[iconName] ?? LucideIcons.mapPin;
}

/// The icon a stop is kept with: the one the lists draw it with, from what
/// serves it.
String favoriteIconNameForStop(Iterable<TransitMode> modes) =>
    switch (headlineMode(modes)) {
      TransitMode.airplane => 'plane',
      TransitMode.rail => 'train',
      TransitMode.subway => 'subway',
      TransitMode.tram => 'tram',
      TransitMode.ferry => 'ferry',
      TransitMode.aerialLift => 'cableCar',
      TransitMode.bus => 'bus',
      TransitMode.coach => 'coach',
      _ => 'stop',
    };
