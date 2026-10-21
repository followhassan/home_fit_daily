import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/local_date.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout.dart';
import '../../domain/plan_scheduler.dart';
import '../../domain/recommendation_service.dart';
import '../../state/custom_workout_controller.dart';
import '../../state/history_controller.dart';
import '../../state/plan_controller.dart';
import '../../state/profile_controller.dart';
import '../../state/recovery_controller.dart';
import '../custom_workouts/workout_builder_screen.dart';
import '../guide/article_screen.dart';
import '../plans/enrollment_screen.dart';
import '../shell/main_shell.dart';
import '../workouts/workout_detail_screen.dart';
import '../workouts/workout_widgets.dart';
import '../workouts/workouts_hub_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    final history = context.watch<HistoryController>();
    final today = history.today;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.hasName ? '$greeting, ${profile.displayName}' : greeting,
              style: context.text.titleLarge,
            ),
            Text(
              '${Formatters.weekdayLong(today.weekday)}, ${Formatters.date(today)}',
              style: context.text.bodySmall,
            ),
          ],
        ),
        actions: const [SettingsAction()],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
          children: const [
            _RecoveryCard(),
            _TodayCard(),
            _WeekCard(),
            _PlanCard(),
            _QuickActions(),
            _Suggestions(),
            _Totals(),
            _TipCard(),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard();

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<RecoveryController>();
    if (recovery.state == RecoveryState.none) return const SizedBox.shrink();
    final checkpoint = recovery.pending;
    final compatible = recovery.state == RecoveryState.available && checkpoint != null;
    final done =
        checkpoint?.engine.results.values.where((r) => r.outcome == StepOutcome.completed).length ??
        0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: AppCard(
        gradient: context.palette.heroGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restore_rounded, color: context.palette.accentInk),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('Unfinished workout', style: context.text.titleMedium)),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              compatible
                  ? '${checkpoint.snapshot.workout.title} was interrupted. $done exercise '
                        '${done == 1 ? 'set' : 'sets'} done. Resume where you left off, or discard it.'
                  : 'A previous workout could not be restored after an app update.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (compatible)
                  FilledButton.icon(
                    onPressed: () => WorkoutLauncher.resume(context, checkpoint),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume'),
                  ),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Discard this session?',
                      message: 'The interrupted session will not be saved to your history.',
                      confirmLabel: 'Discard',
                      destructive: true,
                    );
                    if (ok && context.mounted) await context.read<RecoveryController>().discard();
                  },
                  child: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's plan assignment, or a preference-based suggestion.
class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final plans = context.watch<PlanController>();
    final history = context.watch<HistoryController>();
    final profile = context.watch<ProfileController>().profile;
    final customs = context.read<CustomWorkoutController>();
    final today = history.today;
    final trainedToday = history.hasCompletedOn(today);
    final enrollment = plans.current;
    final progress = plans.progress;

    String eyebrow;
    String title;
    String body;
    Workout? workout;
    String? assignmentId;
    String? planLabel;
    var done = false;
    Widget? extra;

    if (enrollment != null && progress != null && enrollment.status == EnrollmentStatus.paused) {
      eyebrow = 'Your plan';
      title = '${enrollment.planTitle} is paused';
      body =
          'Resume when you are ready – upcoming days will move forward by the time you were away.';
      extra = FilledButton(onPressed: () => plans.resume(), child: const Text('Resume plan'));
    } else if (enrollment != null && progress != null && progress.todayView != null) {
      final view = progress.todayView!;
      final a = view.assignment;
      planLabel = 'Plan day ${a.dayNumber} of 28';
      eyebrow = 'Today · $planLabel';
      if (!a.isTraining) {
        title = 'Rest day';
        body =
            a.note ??
            'Recovery is part of your plan. A relaxed walk or gentle stretch is optional.';
        final stretch = catalog.workout('evening_stretch');
        if (stretch != null) {
          extra = TextButton(
            onPressed: () => Nav.push(context, WorkoutDetailScreen(workout: stretch)),
            child: const Text('Optional: gentle stretch'),
          );
        }
      } else {
        workout = customs.resolve(a.workoutId!);
        title = workout?.title ?? 'Workout unavailable';
        done = view.status == AssignmentStatus.completed;
        body = done
            ? 'Done for today. Great work – rest well.'
            : view.status == AssignmentStatus.skipped
            ? 'You skipped this session.'
            : (workout == null
                  ? 'This workout is not available in this version of the app.'
                  : RecommendationService.explain(workout, catalog.infoFor(workout)));
        assignmentId = done ? null : a.id;
      }
    } else if (trainedToday) {
      eyebrow = 'Today';
      title = 'Nice work today';
      body = 'You completed a workout today. A short stretch helps you cool down.';
      workout = catalog.workout('post_workout_stretch');
    } else if (profile.preferredDays.contains(today.weekday)) {
      final rec = RecommendationService.recommend(
        catalog: catalog,
        profile: profile,
        history: history.sessions,
        today: today,
        limit: 1,
      );
      eyebrow = 'Suggested for today';
      workout = rec.isEmpty ? null : rec.first.workout;
      title = workout?.title ?? 'Pick a workout';
      body = rec.isEmpty ? 'Browse the workouts to find one you like.' : rec.first.explanation;
    } else {
      eyebrow = 'Today';
      title = 'Rest day';
      body =
          'Today is not one of your workout days. Gentle mobility is a nice option if you feel like moving.';
      final rec = RecommendationService.recommend(
        catalog: catalog,
        profile: profile,
        today: today,
        limit: 1,
        where: (w) => w.category == WorkoutCategory.mobility,
      );
      workout = rec.isEmpty ? null : rec.first.workout;
    }

    final w = workout;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: AppCard(
        gradient: context.palette.heroGradient,
        onTap: w == null
            ? null
            : () => Nav.push(
                context,
                WorkoutDetailScreen(
                  workout: w,
                  planAssignmentId: assignmentId,
                  enrollmentId: assignmentId == null ? null : enrollment?.id,
                  planLabel: planLabel,
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: context.text.labelLarge?.copyWith(color: context.palette.accentInk),
            ),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.headlineSmall)),
                if (done)
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.palette.success,
                    semanticLabel: 'Completed',
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(body, style: context.text.bodyMedium),
            if (w != null && !done) ...[
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: () => WorkoutLauncher.start(
                  context,
                  w,
                  planAssignmentId: assignmentId,
                  enrollmentId: assignmentId == null ? null : enrollment?.id,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  eyebrow.startsWith('Today · Plan') ? 'Start today\'s workout' : 'Start',
                ),
              ),
            ],
            if (extra != null) ...[const SizedBox(height: Space.sm), extra],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<HistoryController>().stats;
    final weekStart = stats.today.startOfWeek;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: AppCard(
        semanticLabel:
            '${stats.thisWeekCompleted} of ${stats.weeklyGoal} workouts this week. '
            'Current streak ${stats.currentStreak} days. '
            '${stats.weeklyGoalStreak} weeks on target.',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Row(
                children: [
                  ProgressRing(
                    progress: stats.weeklyProgress,
                    child: Text(
                      '${stats.thisWeekCompleted}/${stats.weeklyGoal}',
                      style: context.text.titleMedium,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This week', style: context.text.titleMedium),
                        Text(
                          stats.thisWeekCompleted >= stats.weeklyGoal
                              ? 'Weekly target reached'
                              : '${stats.weeklyGoal - stats.thisWeekCompleted} to go for your weekly target',
                          style: context.text.bodySmall,
                        ),
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: Space.md,
                          children: [
                            _Mini(
                              icon: Icons.local_fire_department_outlined,
                              text: '${stats.currentStreak}-day streak',
                            ),
                            _Mini(
                              icon: Icons.event_available_outlined,
                              text: '${stats.weeklyGoalStreak} weeks on target',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _DayDot(
                      label: Formatters.weekdayShort(i + 1).substring(0, 1),
                      done: stats.activityOn(weekStart.addDays(i))?.hasCompleted ?? false,
                      partial:
                          stats.activityOn(weekStart.addDays(i))?.partial != null &&
                          (stats.activityOn(weekStart.addDays(i))?.partial ?? 0) > 0,
                      isToday: weekStart.addDays(i) == stats.today,
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Rest days are part of training – weekly consistency matters more than a streak.',
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: context.palette.accentInk),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: context.text.labelMedium)),
    ],
  );
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.done,
    required this.partial,
    required this.isToday,
  });

  final String label;
  final bool done;
  final bool partial;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.premiumPink : palette.surfaceAlt,
            border: isToday ? Border.all(color: palette.accentInk, width: 2) : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 18, color: AppColors.deepBlack)
              : partial
              ? Icon(Icons.remove_rounded, size: 18, color: palette.accentInk)
              : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanController>();
    final enrollment = plans.current;
    final progress = plans.progress;
    if (enrollment == null || progress == null) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.md),
        child: AppCard(
          onTap: () => ShellNavigator.of(context).goTo(ShellTab.plans),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: context.palette.accentInk, size: 32),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow a 4-week plan', style: context.text.titleMedium),
                    Text(
                      'Structured schedules with rest days built in.',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      );
    }
    final next = progress.upcoming.isEmpty ? null : progress.upcoming.first;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: AppCard(
        onTap: () => Nav.push(context, const EnrollmentScreen()),
        child: Row(
          children: [
            ProgressRing(
              progress: progress.completionFraction,
              size: 60,
              child: Text(
                '${(progress.completionFraction * 100).round()}%',
                style: context.text.labelMedium,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enrollment.planTitle, style: context.text.titleMedium),
                  Text(
                    'Week ${progress.currentWeek} of 4 · ${progress.completedCount}/${progress.eligibleCount} sessions'
                    '${progress.missedCount > 0 ? ' · ${progress.missedCount} missed' : ''}',
                    style: context.text.bodySmall,
                  ),
                  if (next != null)
                    Text(
                      'Next: ${Formatters.relativeDay(next.assignment.scheduledDate, progress.today)}',
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final profile = context.watch<ProfileController>().profile;
    final shell = ShellNavigator.of(context);
    final quick = RecommendationService.recommend(
      catalog: catalog,
      profile: profile,
      limit: 1,
      where: (w) => catalog.infoFor(w).estimate.minutes <= 10,
    );
    final stretch = catalog.workout('evening_stretch');
    final actions = <(IconData, String, VoidCallback?)>[
      (
        Icons.bolt_rounded,
        'Quick workout',
        quick.isEmpty ? null : () => WorkoutLauncher.start(context, quick.first.workout),
      ),
      (
        Icons.search_rounded,
        'Browse exercises',
        () => shell.goTo(ShellTab.workouts, section: WorkoutsSection.exercises),
      ),
      (Icons.calendar_month_rounded, 'My plan', () => shell.goTo(ShellTab.plans)),
      (
        Icons.add_circle_outline_rounded,
        'Create workout',
        () => Nav.push(
          context,
          WorkoutBuilderScreen(
            initial: context.read<CustomWorkoutController>().newDraft(),
            isNew: true,
          ),
        ),
      ),
      (
        Icons.favorite_border_rounded,
        'Favorites',
        () => shell.goTo(ShellTab.workouts, section: WorkoutsSection.favorites),
      ),
      (
        Icons.self_improvement_rounded,
        'Stretch',
        stretch == null ? null : () => WorkoutLauncher.start(context, stretch),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick actions'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 520 ? 6 : 3;
            final width = (constraints.maxWidth - Space.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final (icon, label, onTap) in actions)
                  SizedBox(
                    width: width,
                    child: AppCard(
                      onTap: onTap,
                      padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
                      semanticLabel: label,
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Icon(icon, color: context.palette.accentInk),
                            const SizedBox(height: Space.xs),
                            Text(
                              label,
                              style: context.text.labelMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final profile = context.watch<ProfileController>().profile;
    final history = context.watch<HistoryController>();
    final recs = RecommendationService.recommend(
      catalog: catalog,
      profile: profile,
      history: history.sessions,
      today: history.today,
      limit: 5,
    );
    final isNew = !history.stats.hasHistory;
    final starter = catalog.workout('five_minute_starter');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Suggested for you',
          actionLabel: 'See all',
          onAction: () =>
              ShellNavigator.of(context).goTo(ShellTab.workouts, section: WorkoutsSection.workouts),
        ),
        if (isNew && starter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: WorkoutCard(
              workout: starter,
              subtitle: 'New here? This gentle five-minute session is a great first step.',
              onTap: () => Nav.push(context, WorkoutDetailScreen(workout: starter)),
            ),
          ),
        for (final r
            in recs.where((r) => !isNew || r.workout.id != starter?.id).take(isNew ? 3 : 4))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: WorkoutCard(
              workout: r.workout,
              subtitle: r.isExactMatch
                  ? null
                  : 'Closest match to your settings. ${r.workout.description}',
              onTap: () => Nav.push(context, WorkoutDetailScreen(workout: r.workout)),
            ),
          ),
        Text(
          'Suggestions match your level, equipment, preferred duration and impact '
          'setting. They are not medical or personalised coaching advice.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals();

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<HistoryController>().stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'All time'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline_rounded,
                value: '${stats.totalCompleted}',
                label: 'Workouts completed',
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: StatTile(
                icon: Icons.bolt_rounded,
                value: Formatters.minutes(stats.totalActiveSeconds),
                label: 'Active minutes',
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: StatTile(
                icon: Icons.local_fire_department_outlined,
                value: '${stats.longestStreak}',
                label: 'Longest streak',
              ),
            ),
          ],
        ),
        if (!stats.hasHistory)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              'Your numbers start at zero and grow with every workout you complete.',
              style: context.text.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    if (catalog.tips.isEmpty) return const SizedBox.shrink();
    final today = context.watch<HistoryController>().today;
    // A different tip each day, cycling through the list.
    final dayIndex = today.daysSince(const LocalDate(2026, 1, 1)).abs();
    final tip = catalog.tips[dayIndex % catalog.tips.length];
    final article = tip.articleId == null ? null : catalog.article(tip.articleId!);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: AppCard(
        onTap: article == null ? null : () => Nav.push(context, ArticleScreen(article: article)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: context.palette.accentInk),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tip of the day', style: context.text.labelLarge),
                  const SizedBox(height: Space.xs),
                  Text(tip.text, style: context.text.bodyMedium),
                  if (article != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      'Read: ${article.title}',
                      style: context.text.labelMedium?.copyWith(color: context.palette.accentInk),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
