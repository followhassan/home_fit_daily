import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/training_plan.dart';
import '../../state/plan_controller.dart';
import '../shell/main_shell.dart';
import 'enrollment_screen.dart';
import 'plan_detail_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final plans = context.watch<PlanController>();
    final current = plans.current;
    final progress = plans.progress;
    final past = plans.enrollments.where((e) => !e.status.isCurrent).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Plans'), actions: const [SettingsAction()]),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
          children: [
            if (current != null && progress != null) ...[
              const SectionHeader(title: 'Your plan'),
              AppCard(
                gradient: context.palette.heroGradient,
                onTap: () => Nav.push(context, const EnrollmentScreen()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              Text(current.planTitle, style: context.text.titleLarge),
                              Text(
                                current.status == EnrollmentStatus.paused
                                    ? 'Paused'
                                    : 'Week ${progress.currentWeek} of 4 · day ${progress.currentDay}',
                                style: context.text.bodyMedium,
                              ),
                              Text(
                                '${progress.completedCount} of ${progress.eligibleCount} sessions done'
                                '${progress.missedCount > 0 ? ' · ${progress.missedCount} missed' : ''}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    FilledButton(
                      onPressed: () => Nav.push(context, const EnrollmentScreen()),
                      child: const Text('Open schedule'),
                    ),
                  ],
                ),
              ),
            ],
            SectionHeader(title: current == null ? 'Choose a 4-week plan' : 'All plans'),
            if (current == null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(
                  'Each plan schedules every day for four weeks, including rest days. '
                  'You can pause, reschedule missed sessions or leave at any time.',
                  style: context.text.bodyMedium,
                ),
              ),
            for (final plan in catalog.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: PlanCard(plan: plan, isCurrent: current?.planId == plan.id),
              ),
            if (past.isNotEmpty) ...[
              const SectionHeader(title: 'Plan history'),
              for (final e in past)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.status == EnrollmentStatus.completed
                        ? Icons.flag_rounded
                        : Icons.logout_rounded,
                  ),
                  title: Text(e.planTitle),
                  subtitle: Text(
                    '${e.status.label} · started ${e.startDate.toIso()} · '
                    '${plans.progressOf(e).completedCount} sessions completed',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, this.isCurrent = false});

  final TrainingPlan plan;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final info = context.read<Catalog>().infoForPlan(plan);
    return AppCard(
      onTap: () => Nav.push(context, PlanDetailScreen(plan: plan)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.title, style: context.text.titleMedium)),
              if (isCurrent)
                InfoChip(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Current',
                  color: context.palette.accentInk,
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(plan.summary, style: context.text.bodyMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              LevelBadge(level: plan.difficulty),
              const InfoChip(icon: Icons.date_range_rounded, label: '4 weeks'),
              InfoChip(
                icon: Icons.schedule_rounded,
                label: '~${info.averageMinutesPerWeek} min/week',
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
        ],
      ),
    );
  }
}
