import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../models/recent_search.dart';
import 'transitous_geocode_service.dart';

/// The searches the rider ran most recently, for running again.
///
/// Apart from `RecentTripsService`, which keeps connections that were opened:
/// that list shows a journey as it was, this one asks the question again. They
/// live under their own keys, so neither can show up in, or wipe out, the
/// other.
class RecentSearchesService {
  const RecentSearchesService._();

  static const String _key = PrefsKeys.recentSearches;

  /// How many are kept, and so how long the list on the card can get.
  static const int maxSearches = 5;

  /// Puts the search from [from] to [to] at the top, replacing the same search
  /// if it was already there.
  static Future<void> record({
    required TransitousLocationSuggestion from,
    required TransitousLocationSuggestion to,
    DateTime? now,
  }) async {
    final search = RecentSearch(
      from: RecentSearchEnd.of(from),
      to: RecentSearchEnd.of(to),
      searchedAt: now ?? DateTime.now(),
    );

    final searches = await getRecentSearches()
      ..removeWhere((s) => s.identity == search.identity)
      ..insert(0, search);
    await SharedPreferencesAsync().setString(
      _key,
      jsonEncode([for (final s in searches.take(maxSearches)) s.toJson()]),
    );
  }

  /// Most recent first.
  static Future<List<RecentSearch>> getRecentSearches() async {
    try {
      final encoded = await SharedPreferencesAsync().getString(_key);
      if (encoded == null || encoded.isEmpty) return [];

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];

      final searches = <RecentSearch>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          searches.add(RecentSearch.fromJson(item));
        } catch (_) {
          // An entry this build cannot read is dropped, not the whole list.
          continue;
        }
      }
      return searches;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    await SharedPreferencesAsync().remove(_key);
  }
}
