import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/local_date.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_button.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/training_plan.dart';
import '../../domain/plan_scheduler.dart';
import '../../state/plan_controller.dart';
import '../workouts/workout_detail_screen.dart';
import 'enrollment_screen.dart';

/// Plan overview with a week-by-week preview and the start action.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final TrainingPlan plan;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  int _week = 1;
  bool _starting = false;

  Future<void> _start() async {
    final plans = context.read<PlanController>();
    final today = context.read<AppServices>().clock.today();
    final current = plans.current;
    if (current != null) {
      final replace = await confirmAction(
        context,
        title: 'Replace your current plan?',
        message:
            'You are following "${current.planTitle}". Starting a new plan '
            'ends it. Your completed sessions stay in your history.',
        confirmLabel: 'Start new plan',
        destructive: true,
      );
      if (!replace || !mounted) return;
    }
    final start = await showDatePicker(
      context: context,
      helpText: 'Choose a start date',
      initialDate: today.toDateTime(),
      firstDate: today.toDateTime(),
      lastDate: today.addDays(PlanScheduler.maxStartDelayDays).toDateTime(),
    );
    if (start == null || !mounted) return;
    setState(() => _starting = true);
    try {
      await plans.start(widget.plan, LocalDate.fromDateTime(start));
      if (!mounted) return;
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => const EnrollmentScreen()));
    } catch (_) {
      if (mounted) showMessage(context, 'The plan could not be started. Please try again.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final catalog = context.read<Catalog>();
    final info = catalog.infoForPlan(plan);
    final isCurrent = context.select<PlanController, bool>((p) => p.current?.planId == plan.id);
    final days = plan.daysOfWeek(_week).toList();

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 120),
            children: [
              Text(plan.description, style: context.text.bodyLarge),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  LevelBadge(level: plan.difficulty),
                  InfoChip(icon: Icons.flag_outlined, label: plan.goal.label),
                  InfoChip(
                    icon: Icons.schedule_rounded,
                    label: 'About ${info.averageMinutesPerWeek} min per week',
                  ),
                  InfoChip(
                    icon: Icons.event_repeat_rounded,
                    label:
                        '${info.sessionsPerWeek.toStringAsFixed(info.sessionsPerWeek % 1 == 0 ? 0 : 1)} sessions per week',
                  ),
                  InfoChip(
                    icon: info.equipment.isEmpty
                        ? Icons.do_not_disturb_alt_rounded
                        : Icons.handyman_outlined,
                    label: info.equipment.isEmpty
                        ? 'No equipment'
                        : info.equipment.map((e) => e.label).join(' · '),
                  ),
                ],
              ),
              const SectionHeader(title: 'Weekly schedule'),
              Text(plan.weeklySchedule, style: context.text.bodyMedium),
              const SectionHeader(title: 'How it progresses'),
              Text(plan.progressionNotes, style: context.text.bodyMedium),
              const SectionHeader(title: 'Recovery'),
              Text(plan.recoveryGuidance, style: context.text.bodyMedium),
              const SectionHeader(title: 'Week by week'),
              SegmentedButton<int>(
                segments: [
                  for (var w = 1; w <= plan.weekCount; w++)
                    ButtonSegment(value: w, label: Text('Week $w')),
                ],
                selected: {_week},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _week = s.first),
              ),
              const SizedBox(height: Space.sm),
              Text(plan.focusOfWeek(_week), style: context.text.bodyMedium),
              const SizedBox(height: Space.sm),
              for (final day in days) _DayPreview(day: day),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: isCurrent
              ? PremiumButton(
                  label: 'Open my schedule',
                  icon: Icons.calendar_month_rounded,
                  width: double.infinity,
                  onPressed: () => Nav.push(context, const EnrollmentScreen()),
                )
              : PremiumButton(
                  label: 'Start this plan',
                  icon: Icons.play_arrow_rounded,
                  width: double.infinity,
                  loading: _starting,
                  onPressed: _start,
                ),
        ),
      ),
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final workout = day.workoutId == null ? null : context.read<Catalog>().workout(day.workoutId!);
    final info = workout == null ? null : context.read<Catalog>().infoFor(workout);
    final isRest = day.type == PlanDayType.rest;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        padding: const EdgeInsets.all(Space.md),
        onTap: workout == null
            ? null
            : () => Nav.push(context, WorkoutDetailScreen(workout: workout)),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text('Day', style: context.text.labelSmall),
                  Text('${day.dayNumber}', style: context.text.titleLarge),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Icon(
              isRest
                  ? Icons.bedtime_outlined
                  : day.type == PlanDayType.recovery
                  ? Icons.spa_outlined
                  : Icons.fitness_center_rounded,
              color: context.palette.accentInk,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRest ? 'Rest day' : (workout?.title ?? 'Workout'),
                    style: context.text.titleSmall,
                  ),
                  Text(
                    isRest
                        ? (day.note ?? 'Rest and recover')
                        : '${day.type.label} · ${info?.estimate.shortLabel ?? ''}'
                              '${day.note == null ? '' : ' · ${day.note}'}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (workout != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
