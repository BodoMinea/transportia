import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/itinerary.dart';
import '../providers/theme_provider.dart';
import '../utils/geo_utils.dart';
import '../utils/itinerary_leg_utils.dart';
import 'background_navigation_service.dart';
import 'itinerary_navigation_tracker.dart';
import 'location_service.dart';

/// The single source of truth for "is anything being tracked right now."
///
/// Owning this outside any one screen is what lets tracking survive
/// navigating between an itinerary's map view and its detail view (both
/// just watch [active]) while still being able to stop it deliberately when
/// the user actually leaves the itinerary.
class ItineraryTrackingController {
  ItineraryTrackingController._();

  static final ValueNotifier<NavigationProgressState?> active =
      ValueNotifier<NavigationProgressState?>(null);

  static String? _fingerprint;

  /// A cheap "is this the same itinerary" identifier, good enough to keep one
  /// itinerary's screen from stopping a different itinerary's session.
  ///
  /// Built from what a real-time refresh leaves alone: the trips, where it
  /// starts, and the *planned* start time (`sourceJson` is always the
  /// planned snapshot), so the same journey has the same fingerprint before
  /// and after the detail screen refreshes it.
  static String fingerprintFor(Itinerary itinerary) {
    final firstLeg = itinerary.legs.firstOrNull;
    final trips = [
      for (final leg in itinerary.legs) leg.tripId ?? leg.mode,
    ].join('>');
    final plannedStart =
        itinerary.sourceJson?['startTime'] ??
        itinerary.startTime.toUtc().toIso8601String();
    final from = firstLeg == null
        ? ''
        : coordKey(firstLeg.fromLat, firstLeg.fromLon, decimals: 4);
    return '$trips@$from#$plannedStart';
  }

  static bool isTracking(String fingerprint) =>
      active.value != null && _fingerprint == fingerprint;

  /// Starts tracking [legs] from [initialPos] (must be a *fresh* position —
  /// it decides which leg tracking starts on, so a stale/cached one would
  /// pick the wrong leg). No-ops if a session is already active.
  static Future<void> start({
    required List<DisplayLegInfo> legs,
    required String fingerprint,
    required LatLng initialPos,
    int? startLegIndex,
  }) async {
    if (active.value?.isActive == true) return;
    if (await FlutterBackgroundService().isRunning()) {
      _fingerprint = fingerprint;
      final bridge = BackgroundNavigationBridge();
      active.value = bridge;
      _armAutoClearOnArrival(bridge);
      return;
    }

    final tracker = ItineraryNavigationTracker(legs);
    tracker.start(initialPos, startLegIndex: startLegIndex);
    _fingerprint = fingerprint;
    active.value = tracker;
    _armAutoClearOnArrival(tracker);

    unawaited(_upgradeToBackgroundNavigation(tracker, legs, fingerprint));
  }

  /// Clears [active] a few seconds after arrival, regardless of whether any
  /// screen is currently watching — mirrors the brief "Arrived" state the
  /// itinerary map used to manage locally.
  static void _armAutoClearOnArrival(NavigationProgressState tracker) {
    void listener() {
      if (!tracker.arrived) return;
      tracker.removeListener(listener);
      Future.delayed(const Duration(seconds: 4), () {
        if (active.value == tracker) stop();
      });
    }

    tracker.addListener(listener);
  }

  /// If a background session is already running (e.g. reopening the app, or
  /// the app process having been restarted while it kept going) and nothing
  /// local knows about it yet, attach to it. Safe to call on every relevant
  /// screen's load.
  static Future<void> attachIfRunning(String fingerprint) async {
    if (active.value != null) return;
    if (await FlutterBackgroundService().isRunning()) {
      _fingerprint = fingerprint;
      final bridge = BackgroundNavigationBridge();
      active.value = bridge;
      _armAutoClearOnArrival(bridge);
    }
  }

  static Future<void> _upgradeToBackgroundNavigation(
    ItineraryNavigationTracker localTracker,
    List<DisplayLegInfo> legs,
    String fingerprint,
  ) async {
    if (ThemeProvider.instance?.backgroundTrackingEnabled == false) return;

    final granted = await LocationService.ensureBackgroundPermission();
    if (!granted) {
      // Don't keep re-prompting on every future trip once the user has
      // said no; they can re-enable it from Location settings.
      unawaited(ThemeProvider.instance?.setBackgroundTrackingEnabled(false));
      return;
    }
    if (active.value != localTracker) return;

    final legIndex = localTracker.currentLegIndex;
    final pos = await LocationService.currentOrLastKnownLatLng();
    if (pos == null || active.value != localTracker) return;

    localTracker.stop();

    await attachOrStartBackgroundNavigation(
      legs: legs,
      initialPos: pos,
      startLegIndex: legIndex,
    );
    _fingerprint = fingerprint;
    final bridge = BackgroundNavigationBridge();
    active.value = bridge;
    _armAutoClearOnArrival(bridge);
  }

  static void stop() {
    active.value?.stop();
    active.value = null;
    _fingerprint = null;
  }

  static void stopIfMatches(String fingerprint) {
    if (_fingerprint == fingerprint) stop();
  }
}
