import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../theme/app_colors.dart';
import '../../utils/journey_colors.dart';
import '../journey/spine_row.dart';
import '../../models/transitous/enums.dart';
import '../../models/transitous/server_config.dart';
import '../options/icon_controls.dart';
import 'journey_segment.dart';
import 'street_leg_section.dart';
import 'transit_section.dart';
import 'traveller_strip.dart';

/// Which stage of the journey is expanded, if any.
enum _Stage { toStation, transport, fromStation }

/// The options for one search, laid out in the order the journey happens.
///
/// Sits between the origin and destination fields, so the three stages read
/// as the journey rather than as a settings list: what gets you to the first
/// stop, what you ride, and what gets you from the last one.
class JourneySpine extends StatefulWidget {
  const JourneySpine({
    super.key,
    required this.options,
    required this.capabilities,
    required this.onChanged,
    required this.onAddViaStop,
    required this.limitToMyProviders,
    required this.hasRentalProviders,
    required this.onLimitToMyProvidersChanged,
  });

  final RoutingOptions options;

  /// Bounds the budget sliders, so they cannot offer what the server clamps.
  final ServerConfig capabilities;

  final ValueChanged<RoutingOptions> onChanged;

  /// Opens the stop picker; via stops need a search of their own.
  final VoidCallback onAddViaStop;

  /// The app-wide "rent only from my providers" setting. Not part of
  /// [options]: it is saved the moment it changes, rather than with the
  /// search.
  final bool limitToMyProviders;

  /// Whether any provider has been named in the settings. Without one the
  /// limit has nothing to keep to, so turning it on is refused with a hint.
  final bool hasRentalProviders;

  final ValueChanged<bool> onLimitToMyProvidersChanged;

  @override
  State<JourneySpine> createState() => _JourneySpineState();
}

class _JourneySpineState extends State<JourneySpine> {
  final OptionTooltipController _tooltips = OptionTooltipController();

  final Set<_Stage> _open = {};
  bool _paceOpen = false;
  bool _fromBudgetOpen = false;
  bool _toBudgetOpen = false;
  bool _fromModesOpen = false;
  bool _toModesOpen = false;
  bool _modesOpen = false;
  bool _changesOpen = false;

  OptionAnnouncement? _announcement;
  Timer? _announcementTimer;

  @override
  void dispose() {
    _announcementTimer?.cancel();
    _tooltips.dispose();
    super.dispose();
  }

  /// Says what a tap just did, since an icon alone cannot.
  ///
  /// Held as a timer rather than a delayed future so a quick second tap
  /// replaces the first message instead of having it time out on top of the
  /// new one, and so nothing is left running once the card is gone.
  void _announce(String text, {IconData? icon}) {
    _announcementTimer?.cancel();
    setState(() => _announcement = OptionAnnouncement(text, icon: icon));
    _announcementTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() => _announcement = null);
    });
  }

  /// Any change can move a control out from under the finger, and a tooltip
  /// left behind would never be dismissed.
  void _apply(RoutingOptions options) {
    _tooltips.hide();
    widget.onChanged(options);
  }

  void _toggleStage(_Stage stage) {
    _tooltips.hide();
    setState(() {
      if (!_open.remove(stage)) _open.add(stage);
    });
  }

  void _toggleProviderLimit() {
    _tooltips.hide();
    if (!widget.hasRentalProviders) {
      _announce(
        'No providers set. Add yours in Search and routing options',
        icon: LucideIcons.circleAlert,
      );
      return;
    }
    final next = !widget.limitToMyProviders;
    widget.onLimitToMyProvidersChanged(next);
    _announce(
      next ? 'Only your providers' : 'Any provider',
      icon: LucideIcons.scooter,
    );
  }

  Duration get _mileCeiling => widget.capabilities.maxPrePostTransitTime;

  @override
  Widget build(BuildContext context) {
    final options = widget.options;

    return OptionOverlayHost(
      controller: _tooltips,
      announcement: _announcement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On the spine, with no node of its own: who is travelling is not a
          // stage of the journey, but the line still has to run past it. Left
          // off the spine, the dotted rail from the origin marker stopped
          // short of the first stage's ring by the height of this strip.
          SpineRow(
            timeColumn: 0,
            padding: EdgeInsets.zero,
            node: const SizedBox.shrink(),
            nodeCenter: 0,
            railColor: kStreetLegColor,
            railDashed: true,
            firstLineHeight: 0,
            body: Padding(
              // Inside the row, because a gap between rows is a gap in the
              // line.
              padding: const EdgeInsets.only(bottom: 16),
              child: TravellerStrip(
                options: options,
                tooltips: _tooltips,
                paceOpen: _paceOpen,
                onPacePressed: () {
                  _tooltips.hide();
                  setState(() => _paceOpen = !_paceOpen);
                },
                onChanged: (next) {
                  _apply(next);
                  if (next.wheelchairAccessibleOnly !=
                      options.wheelchairAccessibleOnly) {
                    _announce(
                      next.wheelchairAccessibleOnly
                          ? 'Step-free only'
                          : 'Step-free off',
                      icon: LucideIcons.accessibility,
                    );
                  }
                },
              ),
            ),
          ),
          _buildStages(options),
        ],
      ),
    );
  }

  Widget _buildStages(RoutingOptions options) {
    // The street stages take the same neutral the itinerary gives a walk, and
    // the ride takes the accent: the search is a picture of the trip's shape
    // before there is a route to colour it with.
    final accent = AppColors.accentOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySegment(
          color: kStreetLegColor,
          dashed: true,
          icon: mileModesIcon(options.firstMileModes),
          headline: 'To the station',
          summary:
              '${mileModesLabel(options.firstMileModes)} · '
              '${budgetSummaryText(options.maxFirstMileTime)}',
          isOpen: _open.contains(_Stage.toStation),
          onToggle: () => _toggleStage(_Stage.toStation),
          child: StreetLegSection(
            modes: options.firstMileModes,
            budget: options.maxFirstMileTime,
            maxBudget: _mileCeiling,
            formFactors: options.firstMileRentalFormFactors,
            tooltips: _tooltips,
            budgetOpen: _fromBudgetOpen,
            modesOpen: _fromModesOpen,
            onBudgetPressed: () {
              _tooltips.hide();
              setState(() => _fromBudgetOpen = !_fromBudgetOpen);
            },
            onModesPressed: () {
              _tooltips.hide();
              setState(() => _fromModesOpen = !_fromModesOpen);
            },
            onChanged: (choice) {
              _apply(
                options.copyWith(
                  firstMileModes: choice.modes,
                  firstMileRentalFormFactors: choice.formFactors,
                ),
              );
              _announceMileChange(
                options.firstMileModes,
                choice.modes,
                'to the station',
              );
            },
            onBudgetChanged: (budget) =>
                _apply(options.copyWith(maxFirstMileTime: budget)),
            limitToMyProviders: widget.limitToMyProviders,
            onLimitToMyProvidersPressed: _toggleProviderLimit,
          ),
        ),
        JourneySegment(
          color: accent,
          icon: LucideIcons.trainFront,
          headline: 'Public transport',
          summary:
              '${options.transitSelection.summary()} · '
              '${_changesText(options.maxTransfers)}',
          isOpen: _open.contains(_Stage.transport),
          onToggle: () => _toggleStage(_Stage.transport),
          child: TransitSection(
            options: options,
            tooltips: _tooltips,
            modesOpen: _modesOpen,
            changesOpen: _changesOpen,
            onModesPressed: () {
              _tooltips.hide();
              setState(() => _modesOpen = !_modesOpen);
            },
            onChangesPressed: () {
              _tooltips.hide();
              setState(() => _changesOpen = !_changesOpen);
            },
            onViaPressed: widget.onAddViaStop,
            onChanged: (next) {
              _apply(next);
              _announceTransitChange(options, next);
            },
          ),
        ),
        JourneySegment(
          color: kStreetLegColor,
          dashed: true,
          icon: mileModesIcon(options.lastMileModes),
          headline: 'From the station',
          summary:
              '${mileModesLabel(options.lastMileModes)} · '
              '${budgetSummaryText(options.maxLastMileTime)}',
          isOpen: _open.contains(_Stage.fromStation),
          onToggle: () => _toggleStage(_Stage.fromStation),
          child: StreetLegSection(
            modes: options.lastMileModes,
            budget: options.maxLastMileTime,
            maxBudget: _mileCeiling,
            formFactors: options.lastMileRentalFormFactors,
            tooltips: _tooltips,
            budgetOpen: _toBudgetOpen,
            modesOpen: _toModesOpen,
            onBudgetPressed: () {
              _tooltips.hide();
              setState(() => _toBudgetOpen = !_toBudgetOpen);
            },
            onModesPressed: () {
              _tooltips.hide();
              setState(() => _toModesOpen = !_toModesOpen);
            },
            onChanged: (choice) {
              _apply(
                options.copyWith(
                  lastMileModes: choice.modes,
                  lastMileRentalFormFactors: choice.formFactors,
                ),
              );
              _announceMileChange(
                options.lastMileModes,
                choice.modes,
                'from the station',
              );
            },
            onBudgetChanged: (budget) =>
                _apply(options.copyWith(maxLastMileTime: budget)),
            limitToMyProviders: widget.limitToMyProviders,
            onLimitToMyProvidersPressed: _toggleProviderLimit,
          ),
        ),
      ],
    );
  }

  /// Names the mode that was just added or dropped, since the icon alone
  /// cannot say which of the two happened.
  void _announceMileChange(
    List<TransitMode> before,
    List<TransitMode> after,
    String where,
  ) {
    for (final mode in mileModeOrder) {
      final wasOn = before.contains(mode);
      if (wasOn == after.contains(mode)) continue;
      _announce(
        wasOn
            ? 'No ${mileModeLabel(mode).toLowerCase()} $where'
            : '${mileModeLabel(mode)} $where',
        icon: mileModeIcon(mode),
      );
      return;
    }
  }

  /// Names whichever transport-section control changed, so an icon-only tap
  /// still says what it did.
  void _announceTransitChange(RoutingOptions before, RoutingOptions after) {
    if (after.requireBikeTransport != before.requireBikeTransport) {
      _announce(
        after.requireBikeTransport
            ? 'Bike carried on board'
            : 'Bike not carried',
        icon: LucideIcons.bike,
      );
      return;
    }
    if (after.requireCarTransport != before.requireCarTransport) {
      _announce(
        after.requireCarTransport ? 'Car carried on board' : 'Car not carried',
        icon: LucideIcons.car,
      );
      return;
    }
    if (after.noCompulsoryReservation != before.noCompulsoryReservation) {
      _announce(
        after.noCompulsoryReservation
            ? 'Reservation-free only'
            : 'Reservations allowed',
        icon: LucideIcons.ticketX,
      );
      return;
    }
    if (after.maxTransfers != before.maxTransfers) {
      _announce(
        _changesText(
          after.maxTransfers,
        ).replaceRange(0, 1, _changesText(after.maxTransfers)[0].toUpperCase()),
        icon: after.maxTransfers == null
            ? LucideIcons.infinity
            : LucideIcons.waypoints,
      );
      return;
    }
    if (after.transitSelection != before.transitSelection) {
      _announce(after.transitSelection.summary());
    }
  }

  static String _changesText(int? maxTransfers) {
    if (maxTransfers == null) return 'unlimited changes';
    if (maxTransfers == 0) return 'no changes';
    return 'max $maxTransfers ${maxTransfers == 1 ? "change" : "changes"}';
  }
}
