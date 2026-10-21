import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/local_date.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../domain/plan_scheduler.dart';
import '../../state/custom_workout_controller.dart';
import '../../state/plan_controller.dart';
import '../workouts/workout_detail_screen.dart';
import 'plan_detail_screen.dart';

/// The active plan's full schedule and controls.
class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  int? _week;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (success != null && mounted) showMessage(context, success);
    } on ScheduleException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanController>();
    final enrollment = plans.current;
    final progress = plans.progress;
    if (enrollment == null || progress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan')),
        body: const EmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'No active plan',
          message: 'Choose a plan from the Plans tab to get a day-by-day schedule.',
        ),
      );
    }
    final week = _week ?? progress.currentWeek.clamp(1, 4);
    final views = progress.views.where((v) => v.assignment.weekNumber == week).toList();
    final paused = enrollment.status == EnrollmentStatus.paused;
    final plan = context.read<Catalog>().plan(enrollment.planId);

    return Scaffold(
      appBar: AppBar(
        title: Text(enrollment.planTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plan options',
            enabled: !_busy,
            onSelected: (action) async {
              switch (action) {
                case 'pause':
                  await _run(plans.pause, success: 'Plan paused');
                case 'resume':
                  await _run(plans.resume, success: 'Plan resumed');
                case 'details':
                  if (plan != null) await Nav.push(context, PlanDetailScreen(plan: plan));
                case 'restart':
                  if (plan == null) return;
                  final ok = await confirmAction(
                    context,
                    title: 'Restart this plan?',
                    message:
                        'The plan starts again from day 1 today. Completed sessions stay in your history.',
                    confirmLabel: 'Restart',
                  );
                  if (ok && context.mounted) {
                    await _run(
                      () => plans.start(plan, context.read<AppServices>().clock.today()),
                      success: 'Plan restarted',
                    );
                  }
                case 'leave':
                  final ok = await confirmAction(
                    context,
                    title: 'Leave this plan?',
                    message: 'The plan ends now. Completed sessions stay in your history.',
                    confirmLabel: 'Leave plan',
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    await _run(plans.leave);
                    if (context.mounted) Navigator.of(context).pop();
                  }
              }
            },
            itemBuilder: (_) => [
              if (!paused) const PopupMenuItem(value: 'pause', child: Text('Pause plan')),
              if (paused) const PopupMenuItem(value: 'resume', child: Text('Resume plan')),
              const PopupMenuItem(value: 'details', child: Text('Plan details')),
              const PopupMenuItem(value: 'restart', child: Text('Restart from day 1')),
              const PopupMenuItem(value: 'leave', child: Text('Leave plan')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              AppCard(
                child: Row(
                  children: [
                    ProgressRing(
                      progress: progress.completionFraction,
                      child: Text(
                        '${(progress.completionFraction * 100).round()}%',
                        style: context.text.titleSmall,
                      ),
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paused
                                ? 'Paused'
                                : 'Week ${progress.currentWeek} · day ${progress.currentDay}',
                            style: context.text.titleMedium,
                          ),
                          Text(
                            '${progress.completedCount} completed · ${progress.missedCount} missed · '
                            '${progress.skippedCount} skipped · ${progress.upcoming.length} to go',
                            style: context.text.bodySmall,
                          ),
                          Text(
                            'Completion counts training days only; rest days are not counted.',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (paused)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _run(plans.resume, success: 'Plan resumed'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume plan'),
                  ),
                ),
              if (progress.isFinished && !paused)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan finished', style: context.text.titleMedium),
                        Text(
                          'You reached the end of this plan with ${progress.completedCount} completed sessions.',
                          style: context.text.bodyMedium,
                        ),
                        const SizedBox(height: Space.sm),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                    _run(plans.finish, success: 'Plan moved to your plan history'),
                          child: const Text('Mark as finished'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (progress.missed.isNotEmpty && !paused) ...[
                const SectionHeader(title: 'Missed sessions'),
                Text(
                  'Missed sessions stay visible. Move one to today or later, or skip it – '
                  'the rest of the schedule moves with it so workouts are never doubled up.',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Space.sm),
                for (final view in progress.missed)
                  _AssignmentTile(view: view, today: progress.today, busy: _busy, run: _run),
              ],
              const SectionHeader(title: 'Schedule'),
              SegmentedButton<int>(
                segments: [
                  for (var w = 1; w <= 4; w++) ButtonSegment(value: w, label: Text('Week $w')),
                ],
                selected: {week},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _week = s.first),
              ),
              const SizedBox(height: Space.sm),
              if (plan != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(plan.focusOfWeek(week), style: context.text.bodyMedium),
                ),
              for (final view in views)
                _AssignmentTile(view: view, today: progress.today, busy: _busy, run: _run),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.view,
    required this.today,
    required this.busy,
    required this.run,
  });

  final AssignmentView view;
  final LocalDate today;
  final bool busy;
  final Future<void> Function(Future<void> Function(), {String? success}) run;

  @override
  Widget build(BuildContext context) {
    final a = view.assignment;
    final plans = context.read<PlanController>();
    final enrollment = plans.current!;
    final workout = a.workoutId == null
        ? null
        : context.read<CustomWorkoutController>().resolve(a.workoutId!);
    final palette = context.palette;
    final (icon, color) = switch (view.status) {
      AssignmentStatus.completed => (Icons.check_circle_rounded, palette.success),
      AssignmentStatus.today => (Icons.today_rounded, palette.accentInk),
      AssignmentStatus.upcoming => (Icons.radio_button_unchecked_rounded, palette.textSecondary),
      AssignmentStatus.missed => (Icons.error_outline_rounded, palette.warning),
      AssignmentStatus.skipped => (Icons.redo_rounded, palette.textSecondary),
      AssignmentStatus.rest => (Icons.bedtime_outlined, palette.textSecondary),
      AssignmentStatus.onHold => (Icons.pause_circle_outline_rounded, palette.textSecondary),
    };
    final canStart =
        workout != null &&
        (view.status == AssignmentStatus.today ||
            view.status == AssignmentStatus.upcoming ||
            view.status == AssignmentStatus.missed);
    final canMove =
        a.isTraining &&
        (view.status == AssignmentStatus.missed ||
            view.status == AssignmentStatus.today ||
            view.status == AssignmentStatus.upcoming);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
        onTap: workout == null
            ? null
            : () => Nav.push(
                context,
                WorkoutDetailScreen(
                  workout: workout,
                  planAssignmentId: canStart ? a.id : null,
                  enrollmentId: canStart ? enrollment.id : null,
                  planLabel: 'Plan day ${a.dayNumber}',
                ),
              ),
        semanticLabel:
            'Day ${a.dayNumber}, ${Formatters.relativeDay(a.scheduledDate, today)}: '
            '${a.isTraining ? (workout?.title ?? 'Workout') : 'Rest day'}. ${view.status.label}',
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${a.dayNumber} · ${Formatters.relativeDay(a.scheduledDate, today)}',
                    style: context.text.labelMedium,
                  ),
                  Text(
                    a.isTraining ? (workout?.title ?? 'Workout unavailable') : 'Rest day',
                    style: context.text.titleSmall,
                  ),
                  Text(
                    [
                      view.status.label,
                      if (a.type == PlanDayType.recovery) 'Recovery',
                      if (a.wasRescheduled) 'moved from ${Formatters.shortDate(a.originalDate!)}',
                    ].join(' · '),
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (a.isTraining && view.status != AssignmentStatus.completed)
              PopupMenuButton<String>(
                tooltip: 'Session options',
                enabled: !busy,
                onSelected: (action) async {
                  switch (action) {
                    case 'start':
                      await WorkoutLauncher.start(
                        context,
                        workout!,
                        planAssignmentId: a.id,
                        enrollmentId: enrollment.id,
                      );
                    case 'move':
                      final earliest = a.scheduledDate.isAfter(today)
                          ? a.scheduledDate.addDays(1)
                          : today;
                      final picked = await showDatePicker(
                        context: context,
                        helpText: 'Move this session to',
                        initialDate: earliest.toDateTime(),
                        firstDate: earliest.toDateTime(),
                        lastDate: earliest.addDays(14).toDateTime(),
                      );
                      if (picked != null && context.mounted) {
                        await run(
                          () => plans.reschedule(a.id, LocalDate.fromDateTime(picked)),
                          success: 'Session moved. Later days moved with it.',
                        );
                      }
                    case 'skip':
                      await run(() => plans.setSkipped(a.id, true), success: 'Session skipped');
                    case 'unskip':
                      await run(() => plans.setSkipped(a.id, false));
                  }
                },
                itemBuilder: (_) => [
                  if (canStart)
                    const PopupMenuItem(value: 'start', child: Text('Start this session')),
                  if (canMove)
                    const PopupMenuItem(value: 'move', child: Text('Move to another day')),
                  if (view.status != AssignmentStatus.skipped && canMove)
                    const PopupMenuItem(value: 'skip', child: Text('Skip this session')),
                  if (view.status == AssignmentStatus.skipped)
                    const PopupMenuItem(value: 'unskip', child: Text('Undo skip')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
