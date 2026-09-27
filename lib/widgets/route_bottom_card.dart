import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/routing_options.dart';
import '../models/time_selection.dart';
import '../models/transitous/server_config.dart';
import '../models/my_location.dart';
import '../models/trip_history_item.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/route_field_box.dart';
import '../theme/app_colors.dart';
import 'map/bottom_sheet_chrome.dart';
import 'floating_nav_bar.dart';
import 'buttons/primary_button.dart';
import 'search/journey_spine.dart';
import 'search/save_default_row.dart';
import 'search/editable_value.dart';
import 'skeletons/skeleton_shimmer.dart';
import '../theme/app_text.dart';

class BottomCard extends StatefulWidget {
  const BottomCard({
    super.key,
    required this.isCollapsed,
    required this.collapseProgress,
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.fromCtrl,
    required this.toCtrl,
    required this.fromFocusNode,
    required this.toFocusNode,
    required this.showMyLocationDefault,
    required this.onUnfocus,
    required this.onSwapRequested,
    required this.options,
    required this.storedOptions,
    required this.capabilities,
    required this.onOptionsChanged,
    required this.onResetOptions,
    required this.onSaveOptionsAsDefault,
    required this.onAddViaStop,
    required this.onShowMap,
    required this.onFromPressed,
    required this.onToPressed,
    required this.isFromFavourite,
    required this.isToFavourite,
    required this.onToggleFromFavourite,
    required this.onToggleToFavourite,
    required this.routeFieldLink,
    required this.fromLoading,
    required this.toLoading,
    required this.fromSelection,
    required this.toSelection,
    required this.onSearch,
    required this.timeSelectionLayerLink,
    required this.onTimeSelectionTap,
    this.onTimeSelectionTapDown,
    this.onTimeSelectionTapCancel,
    required this.timeSelection,
    required this.recentTrips,
    required this.onRecentTripTap,
    required this.favorites,
    required this.onFavoriteTap,
    required this.hasLocationPermission,
    this.tripsRefreshKey = 0,
  });

  final bool isCollapsed;
  final double collapseProgress;
  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final FocusNode fromFocusNode;
  final FocusNode toFocusNode;
  final bool showMyLocationDefault;
  final VoidCallback onUnfocus;
  final bool Function() onSwapRequested;

  /// The options for the next search, which last only for it.
  final RoutingOptions options;

  /// What a new search starts from, so the card can say when this one differs.
  final RoutingOptions storedOptions;

  /// Bounds the budget sliders to what the connected server will honour.
  final ServerConfig capabilities;

  final ValueChanged<RoutingOptions> onOptionsChanged;
  final VoidCallback onResetOptions;
  final VoidCallback onSaveOptionsAsDefault;
  final VoidCallback onAddViaStop;

  /// Collapses the card so the map is visible.
  final VoidCallback onShowMap;

  /// Opens the place picker for one end or the other.
  final VoidCallback onFromPressed;
  final VoidCallback onToPressed;

  final bool isFromFavourite;
  final bool isToFavourite;
  final VoidCallback onToggleFromFavourite;
  final VoidCallback onToggleToFavourite;

  final LayerLink routeFieldLink;
  final bool fromLoading;
  final bool toLoading;
  final TransitousLocationSuggestion? fromSelection;
  final TransitousLocationSuggestion? toSelection;
  final ValueChanged<TimeSelection> onSearch;
  final LayerLink timeSelectionLayerLink;
  final VoidCallback onTimeSelectionTap;
  final VoidCallback? onTimeSelectionTapDown;
  final VoidCallback? onTimeSelectionTapCancel;
  final TimeSelection timeSelection;
  final List<TripHistoryItem> recentTrips;
  final ValueChanged<TripHistoryItem> onRecentTripTap;
  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onFavoriteTap;
  final bool hasLocationPermission;
  final int tripsRefreshKey;

  @override
  State<BottomCard> createState() => _BottomCardState();
}

class _BottomCardState extends State<BottomCard> {
  /// Holds the row open just long enough to confirm the save, since saving
  /// makes the difference it was reporting disappear.
  bool _savedAsDefault = false;
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    // Focus decides whether the stages or the suggestions get the room, so
    // it has to reach build rather than only the tap handlers.
    widget.fromFocusNode.addListener(_onFocusChanged);
    widget.toFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant BottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromFocusNode != widget.fromFocusNode) {
      oldWidget.fromFocusNode.removeListener(_onFocusChanged);
      widget.fromFocusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.toFocusNode != widget.toFocusNode) {
      oldWidget.toFocusNode.removeListener(_onFocusChanged);
      widget.toFocusNode.addListener(_onFocusChanged);
    }
    // A further edit is a new difference from the stored defaults, so the
    // confirmation stops applying to it.
    if (oldWidget.options != widget.options) {
      _savedTimer?.cancel();
      _savedAsDefault = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _savedTimer?.cancel();
    widget.fromFocusNode.removeListener(_onFocusChanged);
    widget.toFocusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// How long the row confirms the save for, before going back to reporting
  /// the difference from the stored defaults.
  static const Duration _savedConfirmationFor = Duration(milliseconds: 1800);

  void _saveOptionsAsDefault() {
    widget.onSaveOptionsAsDefault();
    setState(() => _savedAsDefault = true);
    _savedTimer?.cancel();
    _savedTimer = Timer(_savedConfirmationFor, () {
      if (mounted) setState(() => _savedAsDefault = false);
    });
  }

  final ScrollController _scroll = ScrollController();

  /// The journey stages. Collapsed, the card is just a search box.
  Widget? _buildSpine() {
    if (widget.isCollapsed) return null;
    return JourneySpine(
      options: widget.options,
      capabilities: widget.capabilities,
      onChanged: widget.onOptionsChanged,
      onAddViaStop: widget.onAddViaStop,
    );
  }

  /// Everything between the handle and the action bar, as one scroll.
  ///
  /// The fields, the journey stages and the trip lists share a single
  /// scrollable so that expanding a stage pushes the rest down rather than
  /// stranding it: collapsing a section to reach the one below it is the
  /// wrong way round.
  Widget _buildScrollableBody(
    BuildContext context, {
    required List<Widget> above,
    required List<Widget> below,
  }) {
    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...above,
          if (!widget.isCollapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: below,
              ),
            ),
            // Clears the pinned action bar's shadow.
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
            return;
          }
          widget.onUnfocus();
        },
        child: Listener(
          onPointerDown: (_) {
            if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
              return;
            }
            widget.onUnfocus();
          },
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BottomSheetHandle(
                  onTap: widget.onHandleTap,
                  onDragStart: widget.onDragStart,
                  onDragUpdate: widget.onDragUpdate,
                  onDragEnd: widget.onDragEnd,
                  bottomGap: 18,
                ),

                Expanded(
                  child: _buildScrollableBody(
                    context,
                    above: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Listener(
                          onPointerDown: (_) {},
                          behavior: HitTestBehavior.opaque,
                          child: GestureDetector(
                            onTap: () {},
                            behavior: HitTestBehavior.opaque,
                            child: RouteFieldBox(
                              fromController: widget.fromCtrl,
                              toController: widget.toCtrl,
                              fromFocusNode: widget.fromFocusNode,
                              toFocusNode: widget.toFocusNode,
                              showMyLocationDefault:
                                  widget.showMyLocationDefault,
                              accentColor: AppColors.accentOf(context),
                              onSwapRequested: widget.onSwapRequested,
                              layerLink: widget.routeFieldLink,
                              fromLoading: widget.fromLoading,
                              toLoading: widget.toLoading,
                              middle: _buildSpine(),
                              timeLine: _buildTimeLine(),
                              footer: _buildSearchButton(),
                              onFromPressed: widget.onFromPressed,
                              onToPressed: widget.onToPressed,
                              isFromFavourite: widget.isFromFavourite,
                              isToFavourite: widget.isToFavourite,
                              onToggleFromFavourite:
                                  widget.onToggleFromFavourite,
                              onToggleToFavourite: widget.onToggleToFavourite,
                            ),
                          ),
                        ),
                      ),

                      // Always offered, not only once something differs:
                      // the row is where the routing options are managed
                      // from, and hunting for a button that appears and
                      // disappears is worse than one that is simply there.
                      if (!widget.isCollapsed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: SaveDefaultRow(
                            saved: _savedAsDefault,
                            differsFromStored:
                                widget.options != widget.storedOptions,
                            onReset: widget.onResetOptions,
                            onSaveAsDefault: _saveOptionsAsDefault,
                          ),
                        ),
                    ],
                    below: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onUnfocus,
                        child: _RecentSections(
                          trips: widget.recentTrips,
                          onTap: widget.onRecentTripTap,
                        ),
                      ),
                      // Clears the floating nav bar, which is a sibling
                      // painted over this card rather than beside it.
                      const SizedBox(height: FloatingNavBar.reservedHeight),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLine() {
    final time = widget.timeSelection;
    return CompositedTransformTarget(
      link: widget.timeSelectionLayerLink,
      child: EditableValue.time(
        label: time.isNow
            ? 'Leave now'
            : '${time.isArriveBy ? 'Arrive' : 'Leave'} '
                  '${time.toDisplayString().replaceFirst('Today ', '')}',
        semanticsLabel: 'Change departure or arrival time',
        onTap: widget.onTimeSelectionTap,
        onTapDown: widget.onTimeSelectionTapDown,
        onTapCancel: widget.onTimeSelectionTapCancel,
      ),
    );
  }

  Widget _buildSearchButton() {
    return PrimaryButton(
      onTap: () => widget.onSearch(widget.timeSelection),
      child: const Center(
        child: Text(
          'Search',
          style: TextStyle(
            color: AppColors.solidWhite,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Recent searches, split by where they started.
///
/// Most searches start from where the rider is standing, and for those the
/// origin says nothing — so they are listed by destination alone, first.
/// Trips that started somewhere chosen keep both ends below them.
class _RecentSections extends StatelessWidget {
  const _RecentSections({required this.trips, required this.onTap});

  final List<TripHistoryItem> trips;
  final ValueChanged<TripHistoryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final destinations = <TripHistoryItem>[];
    final seen = <String>{};
    final elsewhere = <TripHistoryItem>[];
    for (final trip in trips) {
      if (trip.fromName != myLocationName) {
        elsewhere.add(trip);
        continue;
      }
      if (seen.add(trip.toName)) destinations.add(trip);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (destinations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent destinations', style: AppText.heading),
          const SizedBox(height: 12),
          for (final trip in destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _RecentTripTile.destination(
                trip: trip,
                onTap: () => onTap(trip),
              ),
            ),
        ],
        if (elsewhere.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent trips', style: AppText.heading),
          const SizedBox(height: 12),
          for (final trip in elsewhere)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RecentTripTile(trip: trip, onTap: () => onTap(trip)),
            ),
        ],
      ],
    );
  }
}

class _RecentTripTile extends StatefulWidget {
  const _RecentTripTile({required this.trip, required this.onTap})
    : destinationOnly = false;

  /// A trip from My Location, named by where it went.
  const _RecentTripTile.destination({required this.trip, required this.onTap})
    : destinationOnly = true;

  final TripHistoryItem trip;
  final VoidCallback onTap;
  final bool destinationOnly;

  @override
  State<_RecentTripTile> createState() => _RecentTripTileState();
}

class _RecentTripTileState extends State<_RecentTripTile> {
  bool _isLoading = false;

  void _handleTap() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.destinationOnly ? _buildDestination() : _buildTrip();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: _isLoading ? SkeletonShimmer(child: content) : content,
    );
  }

  Widget _tileIcon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: AppColors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: 18, color: AppColors.black),
  );

  Widget _buildDestination() => Row(
    children: [
      _tileIcon(LucideIcons.mapPin),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          widget.trip.toName,
          style: AppText.listTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _buildTrip() {
    return Row(
      children: [
        _tileIcon(LucideIcons.route),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.trip.fromName,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.trip.toName,
                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
