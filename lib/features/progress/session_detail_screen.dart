import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout_session.dart';
import '../../state/history_controller.dart';
import '../../state/plan_controller.dart';
import 'progress_screen.dart';

/// Details of one saved session, using its own workout snapshot.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryController>();
    final session = history.byId(sessionId);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: 'Session not found',
          message: 'This session may have been deleted.',
        ),
      );
    }
    final s = session;
    final (icon, color) = sessionStatusIcon(context, s.status);
    final started = s.startedAtUtc.toLocal();
    final link = s.planAssignmentId == null
        ? null
        : context.read<PlanController>().assignment(s.planAssignmentId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        actions: [
          IconButton(
            tooltip: 'Delete session',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'Delete this session?',
                message:
                    'It will be removed from your history. Your statistics'
                    '${s.planAssignmentId != null ? ' and plan progress' : ''} will be '
                    'recalculated. This cannot be undone.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              try {
                await context.read<HistoryController>().deleteSession(s.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showMessage(context, 'Session deleted');
                }
              } catch (_) {
                if (context.mounted) showMessage(context, 'Could not delete the session.');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              Text(s.title, style: context.text.headlineSmall),
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: Space.xs),
                  Text(s.status.label, style: context.text.titleSmall),
                ],
              ),
              Text(
                '${Formatters.date(s.localCompletionDate)} · started ${Formatters.timeOfDay(started.hour, started.minute)}',
                style: context.text.bodySmall,
              ),
              if (s.importedFromLegacy)
                Text('Imported from an earlier version of the app.', style: context.text.bodySmall),
              const SizedBox(height: Space.lg),
              TileGrid(
                children: [
                  StatTile(
                    icon: Icons.bolt_rounded,
                    value: Formatters.clock(s.activeSeconds),
                    label: 'Active time',
                  ),
                  StatTile(
                    icon: Icons.hourglass_bottom_rounded,
                    value: Formatters.clock(s.restSeconds),
                    label: 'Rest time',
                  ),
                  StatTile(
                    icon: Icons.timer_outlined,
                    value: Formatters.clock(s.elapsedSeconds),
                    label: 'Total time',
                    footnote: 'pauses excluded',
                  ),
                  StatTile(
                    icon: Icons.check_circle_outline_rounded,
                    value: s.stepRecords.isEmpty ? '–' : '${s.completedSteps}/${s.totalSteps}',
                    label: 'Exercises done',
                    footnote: s.skippedSteps > 0 ? '${s.skippedSteps} skipped' : null,
                  ),
                ],
              ),
              if (link != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: InfoChip(
                    icon: Icons.calendar_month_rounded,
                    label: '${link.$1.planTitle} · day ${link.$2.dayNumber}',
                  ),
                ),
              const SectionHeader(title: 'Effort'),
              SegmentedButton<EffortRating>(
                emptySelectionAllowed: true,
                segments: [
                  for (final r in EffortRating.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {?s.effortRating},
                onSelectionChanged: (sel) => context.read<HistoryController>().updateSession(
                  sel.isEmpty ? s.copyWith(clearEffort: true) : s.copyWith(effortRating: sel.first),
                ),
              ),
              const SectionHeader(title: 'Note'),
              _NoteEditor(session: s),
              if (s.stepRecords.isNotEmpty) ...[
                const SectionHeader(title: 'Exercises'),
                for (final r in s.stepRecords)
                  _RecordRow(record: r, name: s.snapshot.nameOf(r.exerciseId)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.session});

  final WorkoutSession session;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.session.note ?? '');
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    await context.read<HistoryController>().updateSession(
      widget.session.copyWith(note: text, clearNote: text.isEmpty),
    );
    if (mounted) {
      setState(() => _dirty = false);
      showMessage(context, 'Note saved');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      TextField(
        controller: _controller,
        maxLength: 500,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Add a note'),
        onChanged: (_) => setState(() => _dirty = true),
      ),
      if (_dirty) FilledButton(onPressed: _save, child: const Text('Save note')),
    ],
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.name});

  final SessionStepRecord record;
  final String name;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final palette = context.palette;
    final (icon, color) = switch (r.outcome) {
      StepOutcome.completed => (Icons.check_rounded, palette.success),
      StepOutcome.skipped => (Icons.skip_next_rounded, palette.warning),
      StepOutcome.stopped => (Icons.stop_rounded, palette.textSecondary),
      StepOutcome.notReached => (Icons.remove_rounded, palette.textSecondary),
    };
    final target = r.execution == ExecutionType.reps
        ? '${r.targetReps} reps'
        : Formatters.duration(r.targetSeconds ?? 0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(name),
      subtitle: Text(
        [
          target,
          if (r.side != Side.none) r.side.label,
          if (r.set > 1) 'set ${r.set}',
          if (r.round > 1) 'round ${r.round}',
          r.outcome.label,
        ].join(' · '),
      ),
    );
  }
}
