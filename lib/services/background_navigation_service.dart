import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../environment.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/leg_helper.dart';
import '../utils/tracking_leg_codec.dart';
import '../utils/tracking_notification_text.dart';
import 'itinerary_navigation_tracker.dart';

const String _channelId = 'itinerary_tracking';
const String _channelName = 'Live trip tracking';
const String _channelDescription =
    'Shows your progress while following a trip.';
const int _notificationId = 4821;

/// How long the service waits for its isolate to say it is ready before
/// sending it the trip regardless.
const Duration _kReadyTimeout = Duration(seconds: 5);

/// How long "You've arrived" stays up before the service stops itself.
const Duration _kArrivedLinger = Duration(seconds: 3);

// Notification action taps land in whatever isolate Android spawns for them,
// which may not share Dart-VM-internal messaging (IsolateNameServer) with the
// long-running background-service isolate. SharedPreferences is backed by
// native storage, so it works as a reliable cross-isolate queue regardless of
// that topology; the service isolate polls it.
const String _pendingActionKey = 'nav_pending_action';
const String _pendingActionSeqKey = 'nav_pending_action_seq';
const Duration _pendingActionPollInterval = Duration(seconds: 1);

bool _configured = false;

Future<void> _ensureConfigured() async {
  if (_configured) return;
  _configured = true;
  final service = FlutterBackgroundService();
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.low,
  );
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: Environment.appName,
      initialNotificationContent: 'Preparing live tracking…',
      foregroundServiceNotificationId: _notificationId,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

/// Starts, or attaches to an already-running, background tracking session.
/// Safe to call repeatedly; never throws.
Future<void> attachOrStartBackgroundNavigation({
  required List<DisplayLegInfo> legs,
  required LatLng initialPos,
  required int startLegIndex,
}) async {
  await _ensureConfigured();
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('queryState');
    return;
  }
  await service.startService();
  await service
      .on('ready')
      .first
      .timeout(_kReadyTimeout, onTimeout: () => null);
  service.invoke('startTracking', {
    'legs': legs.map(displayLegToJson).toList(),
    'startLegIndex': startLegIndex,
    'lat': initialPos.latitude,
    'lon': initialPos.longitude,
  });
}

/// UI-side mirror of the tracker running in the background isolate.
class BackgroundNavigationBridge extends ChangeNotifier
    implements NavigationProgressState {
  BackgroundNavigationBridge() {
    _subscription = FlutterBackgroundService().on('progress').listen(_onEvent);
    FlutterBackgroundService().invoke('queryState');
  }

  StreamSubscription<Map<String, dynamic>?>? _subscription;

  @override
  bool isActive = true;
  @override
  bool arrived = false;
  @override
  bool gpsSignalLost = false;
  @override
  int currentLegIndex = 0;
  @override
  double? remainingWalkMeters;
  @override
  int? remainingStops;

  void _onEvent(Map<String, dynamic>? event) {
    if (event == null) return;
    isActive = event['isActive'] as bool? ?? isActive;
    arrived = event['arrived'] as bool? ?? arrived;
    gpsSignalLost = event['gpsSignalLost'] as bool? ?? gpsSignalLost;
    currentLegIndex = event['currentLegIndex'] as int? ?? currentLegIndex;
    remainingWalkMeters = (event['remainingWalkMeters'] as num?)?.toDouble();
    remainingStops = event['remainingStops'] as int?;
    notifyListeners();
  }

  @override
  void stop() {
    FlutterBackgroundService().invoke('stopTracking');
  }

  @override
  void jumpToLeg(int legIndex) {
    FlutterBackgroundService().invoke('jumpToLeg', {'legIndex': legIndex});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

Map<String, dynamic> _progressToMap(ItineraryNavigationTracker tracker) {
  return {
    'isActive': tracker.isActive,
    'arrived': tracker.arrived,
    'gpsSignalLost': tracker.gpsSignalLost,
    'currentLegIndex': tracker.currentLegIndex,
    'remainingWalkMeters': tracker.remainingWalkMeters,
    'remainingStops': tracker.remainingStops,
  };
}

/// Drives the notification's progress bar from the continuous, GPS-distance
/// based [ItineraryNavigationTracker.legProgress] rather than the stop count,
/// so the bar creeps forward between stops instead of only jumping on
/// arrival, for walks and rides alike.
int _progressPercent(ItineraryNavigationTracker tracker) {
  if (tracker.currentLegIndex >= tracker.legs.length) return 100;
  return (tracker.legProgress * 100).round().clamp(0, 100);
}

/// The size of the mode icon in the notification, in pixels.
const double _kLargeIconSize = 96;

/// Fraction of the large icon the glyph fills.
const double _kLargeIconGlyphFraction = 0.55;

/// Rasterizes a Lucide glyph (the one used in the app for that mode) into a
/// bitmap for the notification's large icon. Null on any failure, so callers
/// can leave the icon out rather than fail the whole notification.
Future<ByteArrayAndroidBitmap?> _renderModeIcon(String mode) async {
  try {
    final iconData = getLegIcon(mode);
    const size = _kLargeIconSize;
    final fontFamily = iconData.fontPackage != null
        ? 'packages/${iconData.fontPackage}/${iconData.fontFamily}'
        : iconData.fontFamily;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = const Color(0xFF2E7D32),
    );

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: size * _kLargeIconGlyphFraction,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              fontFamily: fontFamily,
              color: const Color(0xFFFFFFFF),
            ),
          )
          ..addText(String.fromCharCode(iconData.codePoint));
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(paragraph, Offset(0, (size - paragraph.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null) return;
  unawaited(_queuePendingAction(actionId));
}

Future<void> _queuePendingAction(String actionId) async {
  final prefs = SharedPreferencesAsync();
  final seq = (await prefs.getInt(_pendingActionSeqKey) ?? 0) + 1;
  await prefs.setString(_pendingActionKey, actionId);
  await prefs.setInt(_pendingActionSeqKey, seq);
}

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  ItineraryNavigationTracker? tracker;
  VoidCallback? trackerListener;

  Future<void> showNotification() async {
    final current = tracker;
    if (current == null) return;

    final legIndex = current.currentLegIndex;
    final leg = legIndex < current.legs.length
        ? current.legs[legIndex].leg
        : null;
    final title = leg == null ? 'Trip complete' : trackingTitle(leg);
    final progressLine = trackingProgressLine(
      leg,
      legProgress: current.legProgress,
      remainingWalkMeters: current.remainingWalkMeters,
      remainingStops: current.remainingStops,
      virtualRemaining: current.virtualRemainingNow(),
    );
    final body = current.arrived
        ? "You've arrived"
        : current.gpsSignalLost
        ? '$progressLine (GPS signal lost)'
        : progressLine;

    final actions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        'leg_prev',
        '◀◀',
        showsUserInterface: false,
        cancelNotification: false,
      ),
      if (leg != null && leg.mode != 'WALK') ...[
        const AndroidNotificationAction(
          'stop_prev',
          '◀',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'stop_next',
          '▶',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
      const AndroidNotificationAction(
        'leg_next',
        '▶▶',
        showsUserInterface: false,
        cancelNotification: false,
      ),
      const AndroidNotificationAction(
        'exit',
        '✕',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    final largeIcon = leg == null ? null : await _renderModeIcon(leg.mode);

    await plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          ongoing: !current.arrived,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: _progressPercent(current),
          category: AndroidNotificationCategory.navigation,
          largeIcon: largeIcon,
          actions: actions,
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
    );
  }

  Timer? pendingActionPoll;

  Future<void> stopTracking() async {
    if (trackerListener != null) tracker?.removeListener(trackerListener!);
    tracker?.stop();
    tracker = null;
    pendingActionPoll?.cancel();
    pendingActionPoll = null;
    await plugin.cancel(id: _notificationId);
    await service.stopSelf();
  }

  Future<void> handleActionId(String? actionId) async {
    final current = tracker;
    if (current == null) return;
    switch (actionId) {
      case 'stop_prev':
        current.stepStopBackward();
      case 'stop_next':
        current.stepStopForward();
      case 'leg_prev':
        current.stepLegBackward();
      case 'leg_next':
        current.stepLegForward();
      case 'exit':
        await stopTracking();
    }
  }

  // Primes the "already handled" watermark so a stale action left over from
  // a previous session isn't replayed the moment tracking starts again.
  final prefs = SharedPreferencesAsync();
  var lastHandledActionSeq = await prefs.getInt(_pendingActionSeqKey) ?? 0;

  Future<void> pollPendingAction() async {
    final seq = await prefs.getInt(_pendingActionSeqKey) ?? 0;
    if (seq == lastHandledActionSeq) return;
    lastHandledActionSeq = seq;
    final actionId = await prefs.getString(_pendingActionKey);
    await handleActionId(actionId);
  }

  pendingActionPoll = Timer.periodic(
    _pendingActionPollInterval,
    (_) => unawaited(pollPendingAction()),
  );

  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (response) =>
        unawaited(handleActionId(response.actionId)),
    onDidReceiveBackgroundNotificationResponse:
        _handleBackgroundNotificationResponse,
  );

  service.on('startTracking').listen((event) async {
    if (event == null) return;
    if (trackerListener != null) tracker?.removeListener(trackerListener!);
    tracker?.stop();

    final legs = [
      for (final json in (event['legs'] as List).cast<Map>())
        displayLegFromJson(json.cast<String, dynamic>()),
    ];
    final startLegIndex = event['startLegIndex'] as int? ?? 0;
    final lat = (event['lat'] as num).toDouble();
    final lon = (event['lon'] as num).toDouble();

    final newTracker = ItineraryNavigationTracker(legs);
    tracker = newTracker;
    trackerListener = () async {
      await showNotification();
      service.invoke('progress', _progressToMap(newTracker));
      if (newTracker.arrived) {
        await Future.delayed(_kArrivedLinger);
        if (tracker == newTracker) await stopTracking();
      }
    };
    newTracker.addListener(trackerListener!);
    newTracker.start(LatLng(lat, lon), startLegIndex: startLegIndex);
    await showNotification();
    service.invoke('progress', _progressToMap(newTracker));
  });

  service.on('queryState').listen((event) {
    final current = tracker;
    if (current != null) {
      service.invoke('progress', _progressToMap(current));
    }
  });

  service.on('jumpToLeg').listen((event) {
    final legIndex = event?['legIndex'] as int?;
    if (legIndex != null) tracker?.jumpToLeg(legIndex);
  });

  service.on('stopTracking').listen((event) => unawaited(stopTracking()));

  service.invoke('ready');
}
