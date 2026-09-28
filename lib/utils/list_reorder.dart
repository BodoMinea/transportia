/// Moves [shown]'s item at [from] to [to] and writes the new order back into
/// [all], which [shown] is a filtered view of.
///
/// A list that shows only some of what it keeps — the timetable's stations
/// among all favourites — is reordered by its rows, but the order that is
/// stored is of everything. Each shown item takes a slot a shown item held
/// before, so what the view hides stays exactly where it was.
///
/// [to] is where the item ends up, counted after it is taken out.
/// Items are matched by identity, the way a filter hands them on.
List<T> reorderWithin<T>(List<T> all, List<T> shown, int from, int to) {
  final moved = List.of(shown);
  moved.insert(to, moved.removeAt(from));
  final isShown = Set<T>.identity()..addAll(shown);
  var next = 0;
  return [
    for (final item in all) isShown.contains(item) ? moved[next++] : item,
  ];
}
