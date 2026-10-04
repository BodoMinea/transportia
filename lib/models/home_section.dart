/// The lists under the search on the home screen.
enum HomeSection {
  favorites,
  recentTrips,
  recentSearches,
  departures;

  String get label => switch (this) {
    HomeSection.favorites => 'Favourites',
    HomeSection.recentTrips => 'Recent trips',
    HomeSection.recentSearches => 'Recent searches',
    HomeSection.departures => 'Nearby departures',
  };

  /// What the list holds, in a line for the setting that switches it.
  String get description => switch (this) {
    HomeSection.favorites => 'Your saved places, one tap to go there',
    HomeSection.recentTrips => 'Connections you opened, to look at again',
    HomeSection.recentSearches => 'Searches you ran, to run again',
    HomeSection.departures => 'What leaves the stops around you',
  };
}

/// Whether [section] is shown on the home screen. The list's order is the
/// order they are shown in.
class HomeSectionConfig {
  const HomeSectionConfig({required this.section, required this.enabled});

  final HomeSection section;
  final bool enabled;

  HomeSectionConfig copyWith({bool? enabled}) {
    return HomeSectionConfig(
      section: section,
      enabled: enabled ?? this.enabled,
    );
  }

  String encode() => '${section.name}:${enabled ? 1 : 0}';

  static HomeSectionConfig? decode(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final section = HomeSection.values.where((s) => s.name == parts[0]);
    if (section.isEmpty) return null;
    return HomeSectionConfig(section: section.first, enabled: parts[1] == '1');
  }

  /// Recent trips and nearby departures are what the card has always shown;
  /// favourites and recent searches are there to be switched on. A rider who
  /// never opens the setting sees what they saw before.
  static const List<HomeSectionConfig> defaults = [
    HomeSectionConfig(section: HomeSection.favorites, enabled: false),
    HomeSectionConfig(section: HomeSection.recentTrips, enabled: true),
    HomeSectionConfig(section: HomeSection.recentSearches, enabled: false),
    HomeSectionConfig(section: HomeSection.departures, enabled: true),
  ];

  /// [stored] as the rider left it, plus any section added since that is not
  /// in it yet — appended in its default order, as its default says.
  static List<HomeSectionConfig> reconcile(List<HomeSectionConfig> stored) {
    final known = {for (final config in stored) config.section};
    return [
      ...stored,
      for (final config in defaults)
        if (!known.contains(config.section)) config,
    ];
  }
}
