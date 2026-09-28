import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/my_location.dart';
import '../models/saved_place.dart';
import '../services/favorites_service.dart';
import '../services/saved_places_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../utils/favorite_icons.dart';
import '../utils/haptics.dart';
import '../utils/place_icons.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/buttons/heart_button.dart';
import '../widgets/edit_favorite_overlay.dart';
import 'favourites_map_screen.dart';
import '../theme/app_text.dart';

/// Picks a place, full screen.
///
/// A screen rather than a dropdown under the field: the list has favourites,
/// recent places and geocoder results to show, and an overlay capped at a few
/// hundred pixels has to fight the card it hangs from for the room.
///
/// Thin on purpose — it is [LocationSearchBody] on a page that pops the
/// answer. A screen that is itself a place search renders the body directly.
/// How long typing has to pause before a place lookup is sent.
const Duration _kSearchDebounce = Duration(milliseconds: 220);

class LocationSearchScreen extends StatelessWidget {
  const LocationSearchScreen({
    super.key,
    required this.title,
    required this.bucket,
    this.initialQuery = '',
    this.placeBias,
    this.type,
    this.showFavourites = true,
    this.showMyLocation = false,
  });

  /// Names what is being picked: "Origin", "Destination", "Stop". The map
  /// picker opened from here asks for the same: "Select Origin".
  final String title;

  final SavedPlacesBucket bucket;
  final String initialQuery;
  final LatLng? placeBias;
  final String? type;
  final bool showFavourites;
  final bool showMyLocation;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: title,
      padding: EdgeInsets.zero,
      body: LocationSearchBody(
        bucket: bucket,
        initialQuery: initialQuery,
        placeBias: placeBias,
        type: type,
        showFavourites: showFavourites,
        showMyLocation: showMyLocation,
        mapPickerTitle: 'Select $title',
        onPicked: (suggestion) => Navigator.of(context).pop(suggestion),
      ),
    );
  }
}

/// Picking a place: the field, the favourites, the recents and the results.
///
/// Everything except the page it sits on, so a screen that *is* a place
/// search — the timetable tab — can render it directly instead of keeping its
/// own field and its own copies of the same two lists.
class LocationSearchBody extends StatefulWidget {
  const LocationSearchBody({
    super.key,
    required this.bucket,
    required this.onPicked,
    this.autofocus = true,
    this.initialQuery = '',
    this.placeBias,
    this.type,
    this.showFavourites = true,
    this.showMyLocation = false,
    this.mapPickerTitle = 'Select a place',
    this.mapPickerConfirmLabel = 'Select',
  });

  /// Heading and button of the map picker the field's map icon opens.
  final String mapPickerTitle;
  final String mapPickerConfirmLabel;

  /// What to do with the place that was chosen. The pushed screen pops it;
  /// the timetable tab opens its departures.
  final ValueChanged<TransitousLocationSuggestion> onPicked;

  /// The pushed screen opens for the sake of typing, so it takes the keyboard.
  /// A tab that merely happens to start here should not.
  final bool autofocus;

  /// Which recents to learn from and offer.
  final SavedPlacesBucket bucket;

  final String initialQuery;

  /// Biases the geocoder towards where the rider is.
  final LatLng? placeBias;

  /// Restricts results, e.g. `STOP` for a timetable search.
  final String? type;

  final bool showFavourites;

  /// Offers where the rider is standing as the first answer.
  ///
  /// Only for a route endpoint: a coordinate is not a stop, so a timetable
  /// search has nothing to do with one. Not gated on location permission —
  /// the row is how a rider finds out the app can do this at all, and the
  /// caller asks for permission when it is tapped.
  final bool showMyLocation;

  @override
  State<LocationSearchBody> createState() => _LocationSearchBodyState();
}

class _LocationSearchBodyState extends State<LocationSearchBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  final FocusNode _focus = FocusNode();

  List<TransitousLocationSuggestion> _suggestions = const [];
  List<SavedPlace> _recents = const [];
  List<FavoritePlace> _favourites = const [];
  bool _isFetching = false;
  Timer? _debounce;

  /// Guards against an earlier, slower search overwriting a later one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _favourites = FavoritesService.favoritesListenable.value;
    FavoritesService.favoritesListenable.addListener(_onFavouritesChanged);
    unawaited(FavoritesService.getFavorites());
    unawaited(_loadRecents());
    _controller.addListener(_onQueryChanged);
    // The keyboard is why the pushed screen opened; waiting for a second tap
    // on the field it already put focus on would be a step for nothing. A tab
    // that starts here has its lists to offer first.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    FavoritesService.favoritesListenable.removeListener(_onFavouritesChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFavouritesChanged() {
    if (!mounted) return;
    setState(() => _favourites = FavoritesService.favoritesListenable.value);
  }

  Future<void> _loadRecents() async {
    final places = await SavedPlacesService.loadPlaces(bucket: widget.bucket);
    if (!mounted) return;
    setState(() => _recents = places);
  }

  /// True when this search can only answer with a timetabled stop.
  ///
  /// The geocoder is already told, but the two lists below the field were not,
  /// so a timetable search offered addresses it could not open a departure
  /// board for.
  bool get _stopsOnly => widget.type?.toUpperCase() == 'STOP';

  /// Being a station is not enough — a departure board needs the feed's id for
  /// it, and places kept before the app recorded that have none. Offering one
  /// would fail the moment it was tapped.
  List<FavoritePlace> get _offerableFavourites => _stopsOnly
      ? _favourites.where((f) => f.hasTimetable).toList()
      : _favourites;

  /// A kept place is listed once, under Favourites, rather than again among
  /// the recents — but only when Favourites is actually showing it.
  List<SavedPlace> get _offerableRecents {
    final listedFavourites = widget.showFavourites
        ? {for (final favourite in _offerableFavourites) favourite.id}
        : const <String>{};
    return [
      for (final place in _recents)
        if (_canOffer(place) &&
            !listedFavourites.contains(
              FavoritesService.findAt(place.lat, place.lon)?.id,
            ))
          place,
    ];
  }

  bool _canOffer(SavedPlace place) =>
      !_stopsOnly ||
      (place.type.toUpperCase() == 'STOP' &&
          (place.stopId?.isNotEmpty ?? false));

  String get _query => _controller.text.trim();

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _query;

    // A pasted coordinate is already an answer; there is nothing to look up.
    final coord = TransitousGeocodeService.tryParseLatLon(query);
    if (coord != null) {
      ++_requestId;
      setState(() {
        _suggestions = [TransitousLocationSuggestion.fromLatLon(coord)];
        _isFetching = false;
      });
      return;
    }

    if (query.length < 3) {
      ++_requestId;
      setState(() {
        _suggestions = const [];
        _isFetching = false;
      });
      return;
    }

    setState(() => _isFetching = true);
    _debounce = Timer(_kSearchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await TransitousGeocodeService.fetchSuggestions(
        text: query,
        placeBias: widget.placeBias,
        type: widget.type,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = _prioritiseRecents(results);
        _isFetching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = const [];
        _isFetching = false;
      });
    }
  }

  /// Hoists places this rider has picked before, most-used first.
  ///
  /// The geocoder ranks by its own idea of importance, which cannot know that
  /// you go to one of two identically named stops every day.
  List<TransitousLocationSuggestion> _prioritiseRecents(
    List<TransitousLocationSuggestion> results,
  ) {
    if (_recents.isEmpty) return results;
    final importanceByKey = {
      for (final place in _recents) place.key: place.importance,
    };
    final originalIndex = {
      for (var i = 0; i < results.length; i++) results[i]: i,
    };
    return [...results]..sort((a, b) {
      final aImportance =
          importanceByKey[SavedPlace.buildKey(
            type: a.type,
            lat: a.lat,
            lon: a.lon,
          )];
      final bImportance =
          importanceByKey[SavedPlace.buildKey(
            type: b.type,
            lat: b.lat,
            lon: b.lon,
          )];
      if ((aImportance != null) != (bImportance != null)) {
        return aImportance != null ? -1 : 1;
      }
      if (aImportance != null && bImportance != null) {
        final diff = bImportance.compareTo(aImportance);
        if (diff != 0) return diff;
      }
      return originalIndex[a]!.compareTo(originalIndex[b]!);
    });
  }

  void _pick(TransitousLocationSuggestion suggestion) {
    Haptics.lightTick();
    // Where you are is not a place you searched for, so it does not belong
    // in the list of places you did.
    if (suggestion.id == myLocationSuggestion.id) {
      widget.onPicked(suggestion);
      return;
    }
    // The only place a pick is remembered, and with everything the list
    // needs of it later: the stop id that opens a departure board, and the
    // modes that draw its icon.
    _recents = SavedPlacesService.recordSelection(
      bucket: widget.bucket,
      places: _recents,
      suggestion: suggestion,
    );
    widget.onPicked(suggestion);
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<FavoritePlace>(
      CustomPageRoute(
        child: MapPlacePickerScreen.pick(
          title: widget.mapPickerTitle,
          confirmLabel: widget.mapPickerConfirmLabel,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    _pick(
      TransitousLocationSuggestion(
        id: 'map-${picked.lat}-${picked.lon}',
        name: picked.name,
        lat: picked.lat,
        lon: picked.lon,
        type: 'PLACE',
      ),
    );
  }

  /// Keeps the place, or lets it go, without picking it.
  Future<void> _toggleFavourite(TransitousLocationSuggestion place) async {
    await FavoritesService.toggleAt(
      name: place.name,
      lat: place.lat,
      lon: place.lon,
      type: place.type,
      stopId: place.stopId,
    );
  }

  Widget _heartFor(TransitousLocationSuggestion place) => HeartButton(
    kept: FavoritesService.findAt(place.lat, place.lon) != null,
    placeName: place.name,
    onPressed: () => unawaited(_toggleFavourite(place)),
  );

  Future<void> _editFavourite(FavoritePlace favourite) async {
    Haptics.lightTick();
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EditFavoriteOverlay(
        favorite: favourite,
        onSaved: () {},
        onDeleted: () =>
            unawaited(FavoritesService.removeFavorite(favourite.id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: _buildSearchField(context),
        ),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return CupertinoTextField(
      controller: _controller,
      focusNode: _focus,
      placeholder: 'Search for a place',
      placeholderStyle: TextStyle(
        color: AppColors.black.withValues(alpha: 0.4),
        fontSize: 16,
      ),
      style: TextStyle(color: AppColors.black, fontSize: 16),
      cursorColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.12)),
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(
          LucideIcons.search,
          size: 17,
          color: AppColors.black.withValues(alpha: 0.4),
        ),
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_query.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controller.clear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          // Some places are easier to point at than to name — but a point is
          // not a stop, so a timetable search is not offered one.
          if (!_stopsOnly)
            Semantics(
              button: true,
              label: 'Pick a point on the map',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickOnMap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                  child: Icon(LucideIcons.mapPlus, size: 20, color: accent),
                ),
              ),
            ),
          if (_stopsOnly) const SizedBox(width: 4),
        ],
      ),
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildResults(BuildContext context) {
    final query = _query;
    final hasFullQuery = query.length >= 3;

    if (!hasFullQuery) {
      final favourites = _offerableFavourites;
      final recents = _offerableRecents;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          if (widget.showMyLocation) ...[
            _ResultRow(
              icon: LucideIcons.locateFixed,
              title: myLocationName,
              subtitle: 'Where you are now',
              onTap: () => _pick(myLocationSuggestion),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.showFavourites) ...[
            _sectionHeading('Favourites'),
            if (favourites.isEmpty)
              // Two different emptinesses: nothing kept at all, or things
              // kept that this search cannot use.
              _hint(
                _stopsOnly && _favourites.isNotEmpty
                    ? 'None of your favourites is a stop.'
                    : 'Tap the heart on a place to keep it here.',
              )
            else
              for (final favourite in favourites)
                _FavouriteRow(
                  favourite: favourite,
                  onTap: () => _pick(_favouriteToSuggestion(favourite)),
                  onEdit: () => unawaited(_editFavourite(favourite)),
                ),
            const SizedBox(height: 20),
          ],
          if (recents.isNotEmpty) ...[
            _sectionHeading('Recent'),
            for (final place in recents.take(8))
              _buildPlaceRow(_savedToSuggestion(place), subtitle: place.city),
          ],
          if (favourites.isEmpty && recents.isEmpty && !widget.showFavourites)
            _hint('Start typing to search for a place.'),
        ],
      );
    }

    if (_isFetching && _suggestions.isEmpty) {
      return _hint('Searching…');
    }
    if (_suggestions.isEmpty) {
      return _hint('No matches for “$query”.');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _buildPlaceRow(
          suggestion,
          subtitle: suggestion.defaultArea ?? suggestion.country,
        );
      },
    );
  }

  /// A place that can be picked or kept: a recent, or a search result.
  Widget _buildPlaceRow(
    TransitousLocationSuggestion place, {
    String? subtitle,
  }) => _ResultRow(
    icon: placeIcon(place.type, modes: place.modes),
    title: place.name,
    subtitle: subtitle,
    onTap: () => _pick(place),
    trailing: _heartFor(place),
  );

  Widget _sectionHeading(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: AppColors.black.withValues(alpha: 0.45),
      ),
    ),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Text(text, style: AppText.bodyMuted),
  );

  TransitousLocationSuggestion _favouriteToSuggestion(FavoritePlace f) =>
      TransitousLocationSuggestion(
        id: 'fav-${f.id}',
        stopId: f.stopId,
        name: f.displayName,
        lat: f.lat,
        lon: f.lon,
        type: f.type,
      );

  TransitousLocationSuggestion _savedToSuggestion(SavedPlace place) =>
      TransitousLocationSuggestion(
        id: 'saved-${place.key}',
        stopId: place.stopId,
        name: place.name,
        lat: place.lat,
        lon: place.lon,
        type: place.type,
        modes: place.modes,
      );
}

/// A kept place, with its name and the two ways to rename it.
class _FavouriteRow extends StatelessWidget {
  const _FavouriteRow({
    required this.favourite,
    required this.onTap,
    required this.onEdit,
  });

  final FavoritePlace favourite;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      label: favourite.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The same actions from a long press, since a three-dot button is a
        // small target and holding the row is the habit people already have.
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentWash(accent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  iconForFavorite(favourite.iconName),
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favourite.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.listTitle,
                    ),
                    // Only once the alias says something the name does not,
                    // so an unrenamed favourite is not printed twice.
                    if (favourite.hasAlias)
                      Text(
                        favourite.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.black.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit ${favourite.displayName}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      size: 18,
                      color: AppColors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.listTitle,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.black.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
