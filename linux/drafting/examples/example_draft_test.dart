// An example draft file: copy it, swap in the screens you changed, run it
// with ../render.sh. Not part of `flutter test`, which only looks in test/.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transportia/screens/appearance_screen.dart';
import 'package:transportia/screens/location_search_screen.dart';
import 'package:transportia/services/favorites_service.dart';
import 'package:transportia/services/saved_places_service.dart';

import '../draft_kit.dart';

void main() {
  setUpAll(loadDraftFonts);
  setUp(() {
    resetDraftStorage();
    FavoritesService.favoritesListenable.value = const [];
  });

  // A screen with nothing to set up: pump it and save it.
  testWidgets('appearance', (tester) async {
    await shootScreen(
      tester,
      'appearance',
      const AppearanceScreen(),
      // Taller than a phone, to get the whole scrolling page in one image.
      size: const Size(400, 1400),
    );
  });

  // A screen that shows stored data: seed it through the service first, as
  // the app would have written it.
  testWidgets('location search with a favourite', (tester) async {
    await FavoritesService.saveFavorite(
      FavoritePlace(
        id: 'work',
        name: 'Hauptbahnhof',
        label: 'Work',
        type: 'STOP',
        stopId: 'de:11000:900003201',
        lat: 52.525,
        lon: 13.369,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await shootScreen(
      tester,
      'location_search',
      const LocationSearchScreen(
        title: 'Destination',
        bucket: SavedPlacesBucket.search,
        showMyLocation: true,
      ),
    );
  });

  // Anything the map sits under goes over a stand-in, since MapLibre draws
  // nothing in a test.
  testWidgets('a sheet over the map', (tester) async {
    await shootScreen(
      tester,
      'over_map',
      DraftOverMap(
        sheetTop: 520,
        sheet: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          alignment: Alignment.center,
          child: const Text('your sheet here'),
        ),
      ),
    );
  });
}
