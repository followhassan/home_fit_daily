import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/custom_workout.dart';
import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../data/models/workout.dart';
import '../../domain/custom_workout_validator.dart';
import '../../domain/duration_estimator.dart';
import '../../state/custom_workout_controller.dart';
import '../exercise_library/exercise_library_view.dart';

/// A sensible starting step for [exercise].
WorkoutStep defaultStepFor(Exercise exercise, {StepType type = StepType.main}) {
  final timed = exercise.executionType == ExecutionType.timed;
  return WorkoutStep(
    id: Ids.customStep(),
    exerciseId: exercise.id,
    type: type,
    execution: exercise.executionType,
    durationSeconds: timed ? exercise.defaultDurationSeconds : null,
    repetitions: timed ? null : exercise.defaultRepetitions,
    sets: 1,
    restSeconds: type == StepType.main ? 30 : 10,
    perSide: exercise.isPerSide,
  );
}

/// Create or edit a custom workout.
class WorkoutBuilderScreen extends StatefulWidget {
  const WorkoutBuilderScreen({super.key, required this.initial, required this.isNew});

  final CustomWorkout initial;
  final bool isNew;

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late CustomWorkout _draft = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title);
  late final _description = TextEditingController(text: widget.initial.description);
  CustomWorkoutValidation? _validation;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // A draft created elsewhere (e.g. "add to new workout") starts unsaved.
    _dirty = widget.isNew && widget.initial.steps.isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _update(CustomWorkout draft) {
    setState(() {
      _draft = draft;
      _dirty = true;
      if (_validation != null) {
        _validation = CustomWorkoutValidator.validate(_current, context.read<Catalog>());
      }
    });
  }

  CustomWorkout get _current => _draft.copyWith(title: _title.text, description: _description.text);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await context.read<CustomWorkoutController>().save(_current);
      if (!mounted) return;
      if (result.isValid) {
        _dirty = false;
        Navigator.of(context).pop();
        showMessage(context, widget.isNew ? 'Workout created' : 'Workout saved');
      } else {
        setState(() => _validation = result);
      }
    } catch (_) {
      if (mounted) showMessage(context, 'The workout could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExercise() async {
    final exercise = await Nav.push<Exercise>(context, const _ExercisePickerScreen());
    if (exercise == null || !mounted) return;
    _update(_draft.copyWith(steps: [..._draft.steps, defaultStepFor(exercise)]));
  }

  Future<void> _editStep(int index) async {
    final step = _draft.steps[index];
    final exercise = context.read<Catalog>().exercise(step.exerciseId);
    if (exercise == null) return;
    final updated = await showModalBottomSheet<WorkoutStep>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StepEditor(step: step, exercise: exercise),
    );
    if (updated == null) return;
    final steps = [..._draft.steps]..[index] = updated;
    _update(_draft.copyWith(steps: steps));
  }

  void _duplicateStep(int index) {
    final steps = [..._draft.steps]
      ..insert(index + 1, _draft.steps[index].copyWith(id: Ids.customStep()));
    _update(_draft.copyWith(steps: steps));
  }

  void _removeStep(int index) {
    final steps = [..._draft.steps]..removeAt(index);
    _update(_draft.copyWith(steps: steps));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty &&
        _title.text == widget.initial.title &&
        _description.text == widget.initial.description) {
      return true;
    }
    return confirmAction(
      context,
      title: 'Discard changes?',
      message: 'Your changes to this workout have not been saved.',
      confirmLabel: 'Discard',
      destructive: true,
      cancelLabel: 'Keep editing',
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final v = _validation;
    final estimate = _draft.steps.isEmpty
        ? null
        : DurationEstimator.estimate(
            _current.toWorkout(difficulty: catalog.difficultyOf(_draft.steps)),
            secondsPerRep: catalog.secondsPerRep,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'New workout' : 'Edit workout'),
          actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
        ),
        body: SafeArea(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 120),
              children: [
                if (v != null && !v.isValid)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Semantics(
                      liveRegion: true,
                      child: AppCard(
                        padding: const EdgeInsets.all(Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Please fix the following:', style: context.text.titleSmall),
                            const SizedBox(height: Space.xs),
                            for (final m in v.messages)
                              Text(
                                '• $m',
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: _title,
                  maxLength: CustomWorkoutLimits.titleMax,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Workout name', errorText: v?.titleError),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: Space.sm),
                TextField(
                  controller: _description,
                  maxLength: CustomWorkoutLimits.descriptionMax,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    errorText: v?.descriptionError,
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: Space.sm),
                NumberStepper(
                  label: 'Rounds',
                  value: _draft.rounds,
                  min: 1,
                  max: CustomWorkoutLimits.maxRounds,
                  onChanged: (r) => _update(_draft.copyWith(rounds: r)),
                ),
                if (_draft.rounds > 1)
                  NumberStepper(
                    label: 'Rest between rounds',
                    value: _draft.roundRestSeconds,
                    min: 0,
                    max: CustomWorkoutLimits.maxRest,
                    step: 15,
                    format: (s) => '${s}s',
                    onChanged: (s) => _update(_draft.copyWith(roundRestSeconds: s)),
                  ),
                if (v?.roundsError != null)
                  Text(
                    v!.roundsError!,
                    style: context.text.bodySmall?.copyWith(color: context.palette.error),
                  ),
                SectionHeader(title: 'Exercises (${_draft.steps.length})'),
                if (estimate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: InfoChip(icon: Icons.schedule_rounded, label: estimate.label),
                  ),
                if (v?.stepsError != null)
                  Text(
                    v!.stepsError!,
                    style: context.text.bodyMedium?.copyWith(color: context.palette.error),
                  ),
                if (_draft.steps.isEmpty)
                  const EmptyState(
                    icon: Icons.playlist_add_rounded,
                    title: 'No exercises yet',
                    message:
                        'Add exercises from the library. You can set reps or time, sets, rest and order.',
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _draft.steps.length,
                    onReorderItem: (from, to) {
                      final steps = [..._draft.steps];
                      steps.insert(to, steps.removeAt(from));
                      _update(_draft.copyWith(steps: steps));
                    },
                    itemBuilder: (context, i) {
                      final step = _draft.steps[i];
                      final exercise = catalog.exercise(step.exerciseId);
                      final error = v?.stepErrors[step.id];
                      return Padding(
                        key: ValueKey(step.id),
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: AppCard(
                          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, 0, Space.sm),
                          onTap: () => _editStep(i),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise?.name ?? 'Unavailable exercise',
                                      style: context.text.titleSmall,
                                    ),
                                    Text(
                                      [
                                        if (step.type != StepType.main) step.type.label,
                                        step.targetLabel,
                                        if (step.sets > 1) '${step.sets} sets',
                                        'rest ${step.restSeconds}s',
                                      ].join(' · '),
                                      style: context.text.bodySmall,
                                    ),
                                    if (error != null)
                                      Text(
                                        error,
                                        style: context.text.bodySmall?.copyWith(
                                          color: context.palette.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Exercise options',
                                onSelected: (action) => switch (action) {
                                  'edit' => _editStep(i),
                                  'duplicate' => _duplicateStep(i),
                                  _ => _removeStep(i),
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                                ],
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(Space.md),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    semanticLabel: 'Drag to reorder',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add exercise'),
                ),
                if (estimate != null && estimate.isApproximate)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      'Duration is approximate: repetitions are estimated at about 3 seconds each.',
                      style: context.text.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(_saving ? 'Saving…' : 'Save workout'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExercisePickerScreen extends StatelessWidget {
  const _ExercisePickerScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add exercise')),
    body: SafeArea(child: ExerciseLibraryView(onPick: (e) => Navigator.of(context).pop(e))),
  );
}

class _StepEditor extends StatefulWidget {
  const _StepEditor({required this.step, required this.exercise});

  final WorkoutStep step;
  final Exercise exercise;

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  late WorkoutStep _step = widget.step;

  void _setMode(ExecutionType mode) {
    final e = widget.exercise;
    setState(() {
      _step = _step.copyWith(
        execution: mode,
        durationSeconds: mode == ExecutionType.timed
            ? (_step.durationSeconds ?? e.defaultDurationSeconds ?? 30)
            : null,
        repetitions: mode == ExecutionType.reps
            ? (_step.repetitions ?? e.defaultRepetitions ?? 10)
            : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final modes = [
      if (e.supportsReps) ExecutionType.reps,
      if (e.supportsTimed) ExecutionType.timed,
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(e.name, style: context.text.titleLarge),
          const SectionHeader(title: 'Part of workout'),
          ChoiceChips<StepType>(
            options: StepType.values,
            selected: _step.type,
            labelOf: (t) => t.label,
            onSelected: (t) => setState(() => _step = _step.copyWith(type: t)),
          ),
          if (modes.length > 1) ...[
            const SectionHeader(title: 'Measure by'),
            SegmentedButton<ExecutionType>(
              segments: [
                for (final m in modes)
                  ButtonSegment(
                    value: m,
                    label: Text(m == ExecutionType.reps ? 'Repetitions' : 'Time'),
                  ),
              ],
              selected: {_step.execution},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
          ],
          const SizedBox(height: Space.md),
          if (_step.isTimed)
            NumberStepper(
              label: _step.perSide ? 'Time per side' : 'Time',
              value: _step.durationSeconds ?? 30,
              min: CustomWorkoutLimits.minDuration,
              max: CustomWorkoutLimits.maxDuration,
              step: 5,
              format: Formatters.clock,
              onChanged: (v) => setState(() => _step = _step.copyWith(durationSeconds: v)),
            )
          else
            NumberStepper(
              label: _step.perSide ? 'Reps per side' : 'Repetitions',
              value: _step.repetitions ?? 10,
              min: CustomWorkoutLimits.minReps,
              max: CustomWorkoutLimits.maxReps,
              onChanged: (v) => setState(() => _step = _step.copyWith(repetitions: v)),
            ),
          NumberStepper(
            label: 'Sets',
            value: _step.sets,
            min: 1,
            max: CustomWorkoutLimits.maxSets,
            onChanged: (v) => setState(() => _step = _step.copyWith(sets: v)),
          ),
          NumberStepper(
            label: 'Rest after each set',
            value: _step.restSeconds,
            min: 0,
            max: CustomWorkoutLimits.maxRest,
            step: 5,
            format: (s) => '${s}s',
            onChanged: (v) => setState(() => _step = _step.copyWith(restSeconds: v)),
          ),
          if (e.isPerSide)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Work each side separately'),
              subtitle: Text(
                _step.perSide
                    ? 'Left side, then right side'
                    : 'The target covers both sides (alternate as you go)',
              ),
              value: _step.perSide,
              onChanged: (v) => setState(() => _step = _step.copyWith(perSide: v)),
            ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: () => Navigator.pop(context, _step),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
