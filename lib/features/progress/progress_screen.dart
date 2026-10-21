import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/local_date.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout_session.dart';
import '../../domain/stats_service.dart';
import '../../state/history_controller.dart';
import '../../state/plan_controller.dart';
import '../shell/main_shell.dart';
import 'history_screen.dart';
import 'measurements_screen.dart';
import 'session_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ActivityRange _range = ActivityRange.week;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    final stats = history.stats;
    final plans = context.watch<PlanController>();
    final planProgress = plans.progress;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress'), actions: const [SettingsAction()]),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
          children: [
            if (!stats.hasHistory)
              const Padding(
                padding: EdgeInsets.only(top: Space.sm),
                child: AppCard(
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Your progress will appear here',
                    message:
                        'Complete a workout and you will see your activity, streaks and '
                        'history. Nothing is filled in for you – every number is yours.',
                  ),
                ),
              ),
            const SectionHeader(title: 'Overview'),
            TileGrid(
              children: [
                StatTile(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${stats.totalCompleted}',
                  label: 'Completed workouts',
                  footnote: stats.totalPartial > 0 ? '+${stats.totalPartial} partial' : null,
                ),
                StatTile(
                  icon: Icons.bolt_rounded,
                  value: Formatters.minutes(stats.totalActiveSeconds),
                  label: 'Active minutes',
                ),
                StatTile(
                  icon: Icons.flag_outlined,
                  value: '${stats.thisWeekCompleted}/${stats.weeklyGoal}',
                  label: 'Weekly target',
                  footnote: '${stats.weeklyGoalStreak} weeks on target',
                ),
                StatTile(
                  icon: Icons.local_fire_department_outlined,
                  value: '${stats.currentStreak}',
                  label: 'Day streak',
                  footnote: 'Longest: ${stats.longestStreak}',
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Streaks count consecutive days with a completed workout. Rest days '
              'still matter – the weekly target is the better guide to consistency.',
              style: context.text.bodySmall,
            ),
            if (planProgress != null) ...[
              const SectionHeader(title: 'Plan'),
              AppCard(
                child: Row(
                  children: [
                    ProgressRing(
                      progress: planProgress.completionFraction,
                      size: 56,
                      child: Text(
                        '${(planProgress.completionFraction * 100).round()}%',
                        style: context.text.labelMedium,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        '${planProgress.enrollment.planTitle}\n'
                        '${planProgress.completedCount} completed · ${planProgress.missedCount} missed · '
                        '${planProgress.upcoming.length} upcoming',
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SectionHeader(title: 'Activity'),
            SegmentedButton<ActivityRange>(
              segments: [
                for (final r in ActivityRange.values) ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_range},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const SizedBox(height: Space.md),
            ActivityChart(buckets: stats.buckets(_range), range: _range),
            const SectionHeader(title: 'Calendar'),
            const _CalendarCard(),
            SectionHeader(
              title: 'Recent sessions',
              actionLabel: history.sessions.isEmpty ? null : 'See all',
              onAction: () => Nav.push(context, const HistoryScreen()),
            ),
            if (history.sessions.isEmpty)
              Text('No sessions yet.', style: context.text.bodyMedium)
            else
              for (final s in history.sessions.take(5)) SessionTile(session: s),
            const SectionHeader(title: 'Body measurements'),
            AppCard(
              onTap: () => Nav.push(context, const MeasurementsScreen()),
              child: Row(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: context.palette.accentInk),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      'Optional: track weight or measurements. Nothing is required.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of active minutes per bucket, from saved sessions only.
class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.buckets, required this.range});

  final List<ActivityBucket> buckets;
  final ActivityRange range;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxMinutes = buckets.fold<double>(0, (m, b) => math.max(m, b.activeMinutes));
    final top = maxMinutes <= 0 ? 10.0 : (maxMinutes * 1.2).ceilToDouble();
    final interval = math.max(1.0, (top / 4).ceilToDouble());
    final total = buckets.fold<int>(0, (s, b) => s + b.activeSeconds);
    final summary = buckets
        .where((b) => b.activeSeconds > 0)
        .map((b) => '${_describe(b)}: ${b.activeMinutes.round()} minutes')
        .join('; ');
    final labelEvery = buckets.length > 14 ? 5 : 1;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.lg, Space.sm),
      semanticLabel:
          'Active minutes chart, ${range.label}. '
          '${total == 0 ? 'No activity recorded.' : summary}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Space.sm, bottom: Space.sm),
              child: Text(
                'Active minutes · ${Formatters.minutes(total)} total',
                style: context.text.labelMedium,
              ),
            ),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: top,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(color: palette.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => palette.surfaceAlt,
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${_describe(buckets[group.x])}\n${rod.toY.round()} min',
                        context.text.labelMedium!,
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('min', style: context.text.bodySmall),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: interval,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(value.toInt().toString(), style: context.text.bodySmall),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 ||
                              i >= buckets.length ||
                              i % labelEvery != 0 && i != buckets.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(buckets[i].label, style: context.text.bodySmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].activeMinutes,
                            width: buckets.length > 14 ? 5 : 14,
                            color: AppColors.premiumPink,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Text('No activity in this period yet.', style: context.text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  String _describe(ActivityBucket b) => switch (range) {
    ActivityRange.week || ActivityRange.month => Formatters.shortDate(b.start),
    ActivityRange.weeks => 'Week of ${Formatters.shortDate(b.start)}',
    ActivityRange.months => DateFormat.yMMM().format(b.start.toDateTime()),
  };
}

class _CalendarCard extends StatefulWidget {
  const _CalendarCard();

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    final stats = history.stats;
    final month = stats.today.startOfMonth.addMonthsToStart(_monthOffset);
    final leading = month.weekday - 1; // Monday first
    final days = month.daysInMonth;
    final cells = leading + days;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(() => _monthOffset--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month.toDateTime()),
                  style: context.text.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _monthOffset >= 0 ? null : () => setState(() => _monthOffset++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      Formatters.weekdayShort(i).substring(0, 2),
                      style: context.text.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: (cells / 7).ceil() * 7,
            itemBuilder: (context, i) {
              final dayNumber = i - leading + 1;
              if (dayNumber < 1 || dayNumber > days) return const SizedBox.shrink();
              final date = LocalDate(month.year, month.month, dayNumber);
              final activity = stats.activityOn(date);
              final done = activity?.hasCompleted ?? false;
              final partial = !done && (activity?.partial ?? 0) > 0;
              final isToday = date == stats.today;
              return Semantics(
                button: activity != null,
                label:
                    '${Formatters.date(date)}'
                    '${done
                        ? ', workout completed'
                        : partial
                        ? ', partial session'
                        : ''}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: activity == null
                      ? null
                      : () => _showDay(context, history.sessionsOn(date), date),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.premiumPink : null,
                        border: Border.all(
                          color: isToday
                              ? context.palette.accentInk
                              : partial
                              ? context.palette.accentInk.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: isToday ? 2 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: context.text.labelMedium?.copyWith(
                            color: done ? AppColors.deepBlack : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.lg,
            children: [
              _Legend(filled: true, label: 'Completed'),
              _Legend(filled: false, label: 'Partial'),
            ],
          ),
        ],
      ),
    );
  }

  void _showDay(BuildContext context, List<WorkoutSession> sessions, LocalDate date) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        children: [
          Text(Formatters.date(date), style: context.text.titleLarge),
          const SizedBox(height: Space.sm),
          for (final s in sessions) SessionTile(session: s),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.filled, required this.label});

  final bool filled;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.premiumPink : null,
          border: filled ? null : Border.all(color: context.palette.accentInk, width: 1.5),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.text.bodySmall),
    ],
  );
}

/// One history row.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final today = context.read<HistoryController>().today;
    final (icon, color) = sessionStatusIcon(context, s.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        padding: const EdgeInsets.all(Space.md),
        onTap: () => Nav.push(context, SessionDetailScreen(sessionId: s.id)),
        semanticLabel:
            '${s.title}, ${s.status.label}, '
            '${Formatters.relativeDay(s.localCompletionDate, today)}, '
            '${Formatters.duration(s.activeSeconds)} active',
        child: ExcludeSemantics(
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: context.text.titleSmall),
                    Text(
                      '${Formatters.relativeDay(s.localCompletionDate, today)} · ${s.status.label} · '
                      '${Formatters.duration(s.activeSeconds)} active',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

(IconData, Color) sessionStatusIcon(BuildContext context, SessionStatus status) => switch (status) {
  SessionStatus.completed => (Icons.check_circle_rounded, context.palette.success),
  SessionStatus.partial => (Icons.timelapse_rounded, context.palette.warning),
  SessionStatus.abandoned => (Icons.do_not_disturb_on_outlined, context.palette.textSecondary),
};
