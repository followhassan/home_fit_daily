import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_button.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout_session.dart';
import '../../domain/plan_scheduler.dart';
import '../../state/history_controller.dart';
import '../../state/plan_controller.dart';
import 'player_controller.dart';

/// Shown after a session ends. Lets the user rate effort and add a note.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.outcome});

  final SessionOutcome outcome;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late WorkoutSession? _session = widget.outcome.session;
  late final TextEditingController _note = TextEditingController(text: _session?.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _setEffort(EffortRating rating) async {
    final session = _session;
    if (session == null) return;
    final updated = session.copyWith(effortRating: rating);
    setState(() => _session = updated);
    await context.read<HistoryController>().updateSession(updated);
  }

  Future<void> _done() async {
    final session = _session;
    if (session != null && _note.text.trim() != (session.note ?? '')) {
      setState(() => _saving = true);
      try {
        final text = _note.text.trim();
        await context.read<HistoryController>().updateSession(
          session.copyWith(note: text, clearNote: text.isEmpty),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          showMessage(context, 'Your note could not be saved. Please try again.');
        }
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    final status = o.status;
    final (icon, title, message) = switch (status) {
      SessionStatus.completed => (
        Icons.emoji_events_outlined,
        'Workout complete',
        'Every exercise done. Nice work.',
      ),
      SessionStatus.partial => (
        Icons.flag_outlined,
        'Partially completed',
        'Saved to your history. Partial sessions add to your active minutes '
            'but do not count as completed workouts.',
      ),
      SessionStatus.abandoned => (
        Icons.do_not_disturb_on_outlined,
        'Workout ended',
        'Saved as abandoned. It is listed in your history but does not '
            'count toward your stats or plan.',
      ),
      null => (Icons.info_outline_rounded, 'Workout ended', 'Nothing was saved.'),
    };

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Summary'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                Icon(icon, size: 56, color: context.palette.accentInk),
                const SizedBox(height: Space.md),
                Text(title, style: context.text.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: Space.xs),
                Text(o.title, style: context.text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                Text(message, style: context.text.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: Space.xl),
                TileGrid(
                  children: [
                    StatTile(
                      icon: Icons.check_circle_outline_rounded,
                      value: '${o.completedCount}/${o.totalCount}',
                      label: 'Exercises completed',
                    ),
                    StatTile(
                      icon: Icons.skip_next_rounded,
                      value: '${o.skippedCount}',
                      label: 'Skipped',
                    ),
                    StatTile(
                      icon: Icons.bolt_rounded,
                      value: Formatters.clock(o.activeSeconds),
                      label: 'Active time',
                    ),
                    StatTile(
                      icon: Icons.hourglass_bottom_rounded,
                      value: Formatters.clock(o.restSeconds),
                      label: 'Rest time',
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Total time ${Formatters.clock(o.elapsedSeconds)} (pauses not included)',
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (o.planAssignmentId != null) _PlanResult(outcome: o),
                if (_session != null && status != SessionStatus.abandoned) ...[
                  const SectionHeader(title: 'How did it feel?'),
                  SegmentedButton<EffortRating>(
                    emptySelectionAllowed: true,
                    segments: [
                      for (final r in EffortRating.values)
                        ButtonSegment(value: r, label: Text(r.label)),
                    ],
                    selected: {?_session!.effortRating},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) _setEffort(s.first);
                    },
                  ),
                ],
                if (_session != null) ...[
                  const SectionHeader(title: 'Note (optional)'),
                  TextField(
                    controller: _note,
                    maxLength: 500,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Anything you want to remember about this session',
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                PremiumButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  width: double.infinity,
                  onPressed: _done,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanResult extends StatelessWidget {
  const _PlanResult({required this.outcome});

  final SessionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanController>();
    final link = plans.assignment(outcome.planAssignmentId!);
    if (link == null) return const SizedBox.shrink();
    final (enrollment, assignment) = link;
    final progress = plans.progressOf(enrollment);
    final view = progress.views.firstWhere((v) => v.assignment.id == assignment.id);
    final done = view.status == AssignmentStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: AppCard(
        child: Row(
          children: [
            ProgressRing(
              progress: progress.completionFraction,
              size: 56,
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
                  Text(enrollment.planTitle, style: context.text.titleSmall),
                  Text(
                    done
                        ? 'Day ${assignment.dayNumber} completed · '
                              '${progress.completedCount} of ${progress.eligibleCount} sessions done'
                        : 'Day ${assignment.dayNumber} is still open – only fully '
                              'completed sessions count toward the plan.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
