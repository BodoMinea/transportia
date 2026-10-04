/// A top-level screen reachable from the main navigation shell, addressed by
/// meaning rather than by tab position: the bottom bar is configurable, so
/// "departures" might be the second tab, or not a tab at all.
///
/// Kept apart from `MainNavigationScreen`, which owns the switching, because
/// `MapScreen` also asks for a destination and the shell already imports it.
enum NavDestination { main, departures, savedTrips, settings }
