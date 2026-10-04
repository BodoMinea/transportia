import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/stop_time.dart';
import '../theme/app_colors.dart';
import '../utils/adhoc_tracking.dart';
import 'pressable_highlight.dart';

/// The small navigation icon on a departure that starts following that trip
/// from where the rider stands: they pick where they get off and tracking
/// takes it from there.
class TrackDepartureButton extends StatelessWidget {
  const TrackDepartureButton({super.key, required this.stopTime});

  final StopTime stopTime;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Track ${stopTime.displayName} to ${stopTime.headsign}',
      child: PressableHighlight(
        onPressed: () => unawaited(startAdHocTracking(context, stopTime)),
        borderRadius: BorderRadius.circular(10),
        enableHaptics: false,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            LucideIcons.navigation,
            size: 18,
            color: AppColors.accentOf(context),
          ),
        ),
      ),
    );
  }
}
