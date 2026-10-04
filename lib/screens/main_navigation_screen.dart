import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/nav_destination.dart';
import '../models/tab_bar_item.dart';
import '../providers/theme_provider.dart';
import '../services/plan_request.dart';
import '../services/transitous_geocode_service.dart';
import '../utils/custom_page_route.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/pushed_screen_back_overlay.dart';
import 'map_screen.dart';
import 'saved_trips_screen.dart';
import 'settings_screen.dart';
import 'timetables_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  NavDestination _current = NavDestination.main;
  TransitousLocationSuggestion? _pendingTimetableStop;
  final ValueNotifier<bool> _mapCollapsedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _mapCollapseProgressNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _overlaysVisibleNotifier = ValueNotifier<bool>(
    false,
  );

  /// Search first and Settings last, always; Departures and Saved trips
  /// between them, each only while the rider keeps it as a tab.
  static List<NavDestination> _tabsFor(List<TabBarItemConfig> items) => [
    NavDestination.main,
    if (TabBarItemConfig.isTab(items, TabBarItem.departures))
      NavDestination.departures,
    if (TabBarItemConfig.isTab(items, TabBarItem.savedTrips))
      NavDestination.savedTrips,
    NavDestination.settings,
  ];

  static IconData _iconFor(NavDestination destination) => switch (destination) {
    NavDestination.main => LucideIcons.route,
    NavDestination.departures => LucideIcons.clock,
    NavDestination.savedTrips => LucideIcons.bookmark,
    NavDestination.settings => LucideIcons.settings,
  };

  void _onNavIndexChanged(int index, List<NavDestination> tabs) {
    if (index < 0 || index >= tabs.length) return;
    final destination = tabs[index];
    if (destination != _current) setState(() => _current = destination);
  }

  /// Switches to [destination] when it is a tab, and otherwise opens it over
  /// the tabs with a way back, since those screens rely on being a tab for
  /// theirs. This is the one place that says what "an entry in Settings
  /// instead" means.
  void _goTo(NavDestination destination, List<NavDestination> tabs) {
    if (tabs.contains(destination)) {
      _onNavIndexChanged(tabs.indexOf(destination), tabs);
      return;
    }
    switch (destination) {
      case NavDestination.departures:
        Navigator.of(context).push(
          CustomPageRoute(
            child: PushedScreenBackOverlay(
              child: TimetablesScreen(initialStop: _pendingTimetableStop),
            ),
          ),
        );
      case NavDestination.savedTrips:
        Navigator.of(context).push(
          CustomPageRoute(
            child: const PushedScreenBackOverlay(child: SavedTripsScreen()),
          ),
        );
      case NavDestination.main:
      case NavDestination.settings:
        break; // Always tabs, so never reached here.
    }
  }

  void _handleTimetableRequested(TransitousLocationSuggestion stop) {
    setState(() => _pendingTimetableStop = stop);
    _goTo(NavDestination.departures, _tabsFor(_currentTabBarItems));
  }

  List<TabBarItemConfig> get _currentTabBarItems =>
      context.read<ThemeProvider>().tabBarItems;

  /// A screen elsewhere has asked for a journey to be planned, so the routing
  /// tab comes forward holding it. [MapScreen] clears the request once it has
  /// taken it.
  void _handlePlanRequested() {
    if (PlanRequests.pending.value == null) return;
    setState(() => _current = NavDestination.main);
  }

  @override
  void initState() {
    super.initState();
    PlanRequests.pending.addListener(_handlePlanRequested);
  }

  /// How far the map sheet has to be collapsed before the nav bar starts to
  /// fade, and where it has finished fading. Between the two the bar is on
  /// its way out rather than gone, so a slow drag does not blink it away.
  static const double _kNavFadeStart = 0.6;
  static const double _kNavFadeEnd = 0.9;

  /// How present the floating nav bar should be, given how far the map sheet
  /// is collapsed and whether the map is showing an overlay over everything.
  /// Only the map tab has a sheet that can push the bar away.
  double _navBarVisibility({
    required double progress,
    required bool overlaysVisible,
  }) {
    if (_current != NavDestination.main) return 1.0;
    if (overlaysVisible) return 0.0;
    if (progress <= _kNavFadeStart) return 1.0;
    if (progress >= _kNavFadeEnd) return 0.0;

    final fadeProgress =
        (progress - _kNavFadeStart) / (_kNavFadeEnd - _kNavFadeStart);
    return 1.0 - Curves.easeInOut.transform(fadeProgress);
  }

  @override
  void dispose() {
    PlanRequests.pending.removeListener(_handlePlanRequested);
    _mapCollapsedNotifier.dispose();
    _mapCollapseProgressNotifier.dispose();
    _overlaysVisibleNotifier.dispose();
    super.dispose();
  }

  Widget _screenFor(NavDestination destination, List<NavDestination> tabs) {
    return switch (destination) {
      NavDestination.main => MapScreen(
        onCollapseChanged: (isCollapsed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapCollapsedNotifier.value = isCollapsed;
          });
        },
        onCollapseProgressChanged: (progress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapCollapseProgressNotifier.value = progress;
          });
        },
        onOverlayVisibilityChanged: (overlaysVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _overlaysVisibleNotifier.value = overlaysVisible;
          });
        },
        onTabChangeRequested: (requested) => _goTo(requested, tabs),
        onTimetableRequested: _handleTimetableRequested,
      ),
      NavDestination.departures => TimetablesScreen(
        initialStop: _pendingTimetableStop,
      ),
      NavDestination.savedTrips => const SavedTripsScreen(),
      NavDestination.settings => const SettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsFor(context.watch<ThemeProvider>().tabBarItems);
    // A tab switched off while it was showing leaves the rider on Search.
    final currentIndex = tabs.contains(_current) ? tabs.indexOf(_current) : 0;

    return PopScope(
      canPop: _current == NavDestination.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _current = NavDestination.main);
      },
      child: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: [
              // Keyed by destination, so a screen keeps its state when the
              // tab before it is switched off and its index moves.
              for (final destination in tabs)
                KeyedSubtree(
                  key: ValueKey(destination),
                  child: _screenFor(destination, tabs),
                ),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: ValueListenableBuilder<double>(
                valueListenable: _mapCollapseProgressNotifier,
                builder: (context, progress, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _overlaysVisibleNotifier,
                    builder: (context, overlaysVisible, child) {
                      return FloatingNavBar(
                        currentIndex: currentIndex,
                        icons: [for (final d in tabs) _iconFor(d)],
                        onIndexChanged: (index) =>
                            _onNavIndexChanged(index, tabs),
                        visibility: _navBarVisibility(
                          progress: progress,
                          overlaysVisible: overlaysVisible,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
