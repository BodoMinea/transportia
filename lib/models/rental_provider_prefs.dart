/// A provider group the rider has an account with.
///
/// Keeps the name next to the id, so the pick can be shown without the
/// provider list — offline, or after the group has dropped out of it.
class PickedProviderGroup {
  const PickedProviderGroup({required this.id, required this.name});

  /// The group id MOTIS takes as `…RentalProviderGroups`.
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static PickedProviderGroup? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    return PickedProviderGroup(id: id, name: name is String ? name : id);
  }
}

/// Which rental providers the rider can use, and whether searches keep to
/// them.
///
/// App-wide rather than per search: accounts do not change between trips.
class RentalProviderPrefs {
  const RentalProviderPrefs({this.limit = false, this.groups = const []});

  static const RentalProviderPrefs none = RentalProviderPrefs();

  /// Whether rentals are limited to [groups].
  final bool limit;
  final List<PickedProviderGroup> groups;

  /// Limiting to nothing would rule out every rental, so an empty list
  /// counts as no limit whatever [limit] says.
  bool get isActive => limit && groups.isNotEmpty;

  /// The group ids to send, or none when the limit is off.
  List<String> get activeGroupIds =>
      isActive ? [for (final group in groups) group.id] : const [];

  bool contains(String id) => groups.any((group) => group.id == id);

  /// Adds [group]. The first one also turns the limit on, so naming your
  /// providers has an effect without a second trip to the search screen.
  RentalProviderPrefs add(PickedProviderGroup group) {
    if (contains(group.id)) return this;
    return RentalProviderPrefs(
      limit: groups.isEmpty ? true : limit,
      groups: [...groups, group],
    );
  }

  /// Removes the group with [id]; removing the last one turns the limit off.
  RentalProviderPrefs remove(String id) {
    final next = [
      for (final group in groups)
        if (group.id != id) group,
    ];
    return RentalProviderPrefs(
      limit: next.isEmpty ? false : limit,
      groups: next,
    );
  }

  RentalProviderPrefs withLimit(bool limit) =>
      RentalProviderPrefs(limit: limit, groups: groups);

  Map<String, dynamic> toJson() => {
    'limit': limit,
    'groups': [for (final group in groups) group.toJson()],
  };

  factory RentalProviderPrefs.fromJson(Map<String, dynamic> json) {
    final raw = json['groups'];
    return RentalProviderPrefs(
      limit: json['limit'] as bool? ?? false,
      groups: [
        if (raw is List)
          for (final entry in raw)
            if (PickedProviderGroup.fromJson(entry) case final group?) group,
      ],
    );
  }
}
