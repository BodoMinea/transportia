/// The tabs the rider may take off the bottom bar.
enum TabBarItem {
  departures,
  savedTrips;

  String get label => switch (this) {
    TabBarItem.departures => 'Departures',
    TabBarItem.savedTrips => 'Saved trips',
  };
}

/// Whether [item] is a tab in the bottom bar or, when it is not, an entry in
/// Settings instead.
///
/// Search and Settings are always tabs and are not configurable; this covers
/// the two slots between them.
class TabBarItemConfig {
  const TabBarItemConfig({required this.item, required this.enabledAsTab});

  final TabBarItem item;
  final bool enabledAsTab;

  TabBarItemConfig copyWith({bool? enabledAsTab}) {
    return TabBarItemConfig(
      item: item,
      enabledAsTab: enabledAsTab ?? this.enabledAsTab,
    );
  }

  String encode() => '${item.name}:${enabledAsTab ? 1 : 0}';

  static TabBarItemConfig? decode(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final item = TabBarItem.values.where((i) => i.name == parts[0]);
    if (item.isEmpty) return null;
    return TabBarItemConfig(item: item.first, enabledAsTab: parts[1] == '1');
  }

  /// Every item is a tab, which is how the bar looked before it was
  /// configurable.
  static const List<TabBarItemConfig> defaults = [
    TabBarItemConfig(item: TabBarItem.departures, enabledAsTab: true),
    TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: true),
  ];

  /// [stored] as the rider left it, plus any item added since that is not in
  /// it yet, taken from [defaults].
  static List<TabBarItemConfig> reconcile(List<TabBarItemConfig> stored) {
    final known = {for (final config in stored) config.item};
    return [
      ...stored,
      for (final config in defaults)
        if (!known.contains(config.item)) config,
    ];
  }

  /// Whether [item] is a tab, per [configs]. An item with no entry is taken
  /// from [defaults].
  static bool isTab(List<TabBarItemConfig> configs, TabBarItem item) {
    for (final config in configs) {
      if (config.item == item) return config.enabledAsTab;
    }
    return defaults.firstWhere((c) => c.item == item).enabledAsTab;
  }
}
