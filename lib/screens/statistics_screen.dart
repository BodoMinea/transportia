import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/saved_trip.dart';
import '../providers/theme_provider.dart';
import '../services/saved_trips_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/duration_formatter.dart';
import '../utils/leg_helper.dart';
import '../utils/trip_stats.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/section_title.dart';

/// Basic stats worked out from the saved trips. Nothing else records the
/// trips a rider takes, so this only knows what was kept: a partial picture,
/// not a travel log.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.clock = DateTime.now});

  /// What "now" is, which decides which saved trips are already over.
  final DateTime Function() clock;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await SavedTripsService.getSavedTrips();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return AppPageScaffold(
      title: 'Statistics',
      scrollable: true,
      padding: const EdgeInsets.all(20),
      body: _isLoading
          ? const SizedBox(height: 200)
          : ValueListenableBuilder<List<SavedTrip>>(
              valueListenable: SavedTripsService.savedTripsListenable,
              builder: (context, trips, _) => _buildContent(context, trips),
            ),
    );
  }

  Widget _buildContent(BuildContext context, List<SavedTrip> trips) {
    final stats = TripStats.compute(trips, now: widget.clock());
    final accent = AppColors.accentOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconHeader(
          icon: LucideIcons.chartPie,
          title: 'Your Travel Stats',
          subtitle: 'Based on your saved trips',
          iconColor: accent,
        ),
        const SizedBox(height: 16),
        const _WipBadge(),
        const SizedBox(height: 32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(text: 'Saved Trips'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.history,
                    label: 'Past',
                    value: '${stats.pastCount}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.calendarClock,
                    label: 'Upcoming',
                    value: '${stats.upcomingCount}',
                  ),
                ),
              ],
            ),
            if (stats.pastCount == 0)
              ..._buildEmpty()
            else
              ..._buildPastTripStats(stats),
            const SizedBox(height: 32),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildEmpty() => [
    const SizedBox(height: 32),
    Text(
      'Save a few trips that have happened to see walking and transit time, '
      'a mode and time-of-day breakdown, and your most common places here.',
      style: AppText.bodyFaint,
    ),
  ];

  List<Widget> _buildPastTripStats(TripStats stats) {
    final totalModeSeconds = stats.totalModeTime.inSeconds;
    return [
      const SizedBox(height: 32),
      const SectionTitle(text: 'Time Spent (past trips)'),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: LucideIcons.footprints,
              label: 'Walking',
              value: formatDuration(stats.walkingTime.inSeconds),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: LucideIcons.trainFront,
              label: 'Public transit',
              value: formatDuration(stats.transitTime.inSeconds),
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      const SectionTitle(text: 'Mode Share'),
      const SizedBox(height: 8),
      Text('Time spent per mode of transport', style: AppText.bodyFaint),
      const SizedBox(height: 16),
      _BarList(
        entries: [
          for (final entry in stats.timeByMode)
            _BarEntry(
              label: getTransitModeName(entry.key),
              detail: formatDuration(entry.value.inSeconds),
              fraction: totalModeSeconds == 0
                  ? 0
                  : entry.value.inSeconds / totalModeSeconds,
              icon: getLegIcon(entry.key),
            ),
        ],
      ),
      const SizedBox(height: 32),
      const SectionTitle(text: 'Time of Day'),
      const SizedBox(height: 8),
      Text('When your saved trips depart', style: AppText.bodyFaint),
      const SizedBox(height: 16),
      _BarList(
        entries: [
          for (final entry in stats.tripsByDayPart)
            _BarEntry(
              label: entry.key.label,
              detail: '${entry.value}',
              fraction: entry.value / stats.pastCount,
            ),
        ],
      ),
      const SizedBox(height: 32),
      const SectionTitle(text: 'Top Places'),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: LucideIcons.mapPin,
              label: 'Top origin',
              value: stats.topOrigin ?? '—',
              valueMaxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: LucideIcons.flag,
              label: 'Top destination',
              value: stats.topDestination ?? '—',
              valueMaxLines: 2,
            ),
          ),
        ],
      ),
    ];
  }
}

class _WipBadge extends StatelessWidget {
  const _WipBadge();

  static const Color _ink = Color(0xFF8A6D00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.construction, size: 14, color: _ink),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Work in progress — more stats coming later',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _BarEntry {
  const _BarEntry({
    required this.label,
    required this.detail,
    required this.fraction,
    this.icon,
  });

  final String label;
  final String detail;
  final double fraction;
  final IconData? icon;
}

class _BarList extends StatelessWidget {
  const _BarList({required this.entries});

  final List<_BarEntry> entries;

  static const List<Color> _palette = [
    Color(0xFF0B8F96),
    Color(0xFFD04E37),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
    Color(0xFF5856D6),
  ];

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('Not enough data yet.', style: AppText.bodyFaint);
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _BarRow(entry: entries[i], color: _palette[i % _palette.length]),
          if (i != entries.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.entry, required this.color});

  final _BarEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (entry.icon != null) ...[
              Icon(entry.icon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            Text(
              entry.detail,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.black.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 8,
                    width: constraints.maxWidth,
                    color: AppColors.black.withValues(alpha: 0.06),
                  ),
                  Container(
                    height: 8,
                    width: constraints.maxWidth * entry.fraction.clamp(0, 1),
                    color: color,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
