import '../models/transitous/rentals_response.dart';

/// Most suggestions shown under the provider field at once.
const int kMaxProviderSuggestions = 6;

/// Provider groups whose name contains [query], for the provider field.
///
/// Groups are offered exactly as the server lists them: some companies come
/// as one group per city, and telling which belong together is left to the
/// data rather than guessed here.
///
/// Case and accents are ignored, so "velo" finds "Vélomagg". Groups already
/// in [picked] are left out. Those in [nearby] come first, then the rest
/// alphabetically. An empty query suggests nothing: the list is too long to
/// browse.
List<RentalProviderGroup> suggestProviders(
  String query,
  List<RentalProviderGroup> catalogue, {
  Set<String> picked = const {},
  Set<String> nearby = const {},
  int limit = kMaxProviderSuggestions,
}) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return const [];

  final matches = [
    for (final group in catalogue)
      if (group.id.isNotEmpty &&
          !picked.contains(group.id) &&
          foldForSearch(group.name).contains(needle))
        group,
  ];
  matches.sort((a, b) {
    final byNearby = (nearby.contains(a.id) ? 0 : 1).compareTo(
      nearby.contains(b.id) ? 0 : 1,
    );
    if (byNearby != 0) return byNearby;
    return foldForSearch(a.name).compareTo(foldForSearch(b.name));
  });
  return matches.take(limit).toList();
}

/// Lower case with Latin accents dropped and runs of spaces collapsed, for
/// matching typed text against names.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final isSpace = char.trim().isEmpty;
    if (isSpace && lastWasSpace) continue;
    buffer.write(isSpace ? ' ' : (_kFolded[char] ?? char));
    lastWasSpace = isSpace;
  }
  return buffer.toString().trim();
}

const Map<String, String> _kFolded = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ę': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ő': 'o',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ș': 's',
  'ş': 's',
  'ß': 'ss',
  'ť': 't',
  'ț': 't',
  'ţ': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'æ': 'ae',
  'œ': 'oe',
};
