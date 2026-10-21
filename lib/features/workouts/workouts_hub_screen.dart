import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/personal_records.dart';
import '../../domain/filters.dart';
import '../../state/custom_workout_controller.dart';
import '../../state/favorites_controller.dart';
import '../custom_workouts/workout_builder_screen.dart';
import '../exercise_library/exercise_detail_screen.dart';
import '../exercise_library/exercise_library_view.dart';
import '../shell/main_shell.dart';
import 'workout_detail_screen.dart';
import 'workout_widgets.dart';

enum WorkoutsSection {
  workouts('Workouts'),
  exercises('Exercises'),
  favorites('Favorites'),
  mine('My workouts');

  const WorkoutsSection(this.label);
  final String label;
}

/// The Workouts tab: ready-made workouts, the exercise library, favorites
/// and the user's own workouts.
class WorkoutsHubScreen extends StatefulWidget {
  const WorkoutsHubScreen({super.key, required this.section});

  final ValueNotifier<WorkoutsSection> section;

  @override
  State<WorkoutsHubScreen> createState() => _WorkoutsHubScreenState();
}

class _WorkoutsHubScreenState extends State<WorkoutsHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: WorkoutsSection.values.length,
    vsync: this,
    initialIndex: widget.section.value.index,
  );

  @override
  void initState() {
    super.initState();
    widget.section.addListener(_onSectionRequested);
  }

  void _onSectionRequested() => _tabs.animateTo(widget.section.value.index);

  @override
  void dispose() {
    widget.section.removeListener(_onSectionRequested);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: const [SettingsAction()],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final s in WorkoutsSection.values) Tab(text: s.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          WorkoutListView(),
          ExerciseLibraryView(),
          _FavoritesView(),
          _MyWorkoutsView(),
        ],
      ),
    );
  }
}

/// Searchable, filterable, sortable list of ready-made workouts.
class WorkoutListView extends StatefulWidget {
  const WorkoutListView({super.key});

  @override
  State<WorkoutListView> createState() => _WorkoutListViewState();
}

class _WorkoutListViewState extends State<WorkoutListView> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  WorkoutFilter _filter = const WorkoutFilter();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(WorkoutFilter f) => setState(() => _filter = f);

  void _clearAll() {
    _search.clear();
    _set(WorkoutFilter(sort: _filter.sort));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<WorkoutFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WorkoutFilterSheet(initial: _filter),
    );
    if (result != null) _set(result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final catalog = context.read<Catalog>();
    final favorites = context.watch<FavoritesController>();
    final results = _filter.apply(
      catalog,
      catalog.workouts,
      isFavorite: favorites.isWorkoutFavorite,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search workouts',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _set(_filter.copyWith(query: ''));
                            },
                          ),
                  ),
                  onChanged: (q) => _set(_filter.copyWith(query: q)),
                ),
              ),
              const SizedBox(width: Space.sm),
              Badge(
                isLabelVisible: _filter.activeCount > 0,
                label: Text('${_filter.activeCount}'),
                child: IconButton.filledTonal(
                  tooltip: 'Filter and sort',
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: FilterChip(
                  avatar: const Icon(Icons.favorite_border_rounded, size: 16),
                  label: const Text('Favorites'),
                  selected: _filter.favoritesOnly,
                  onSelected: (v) => _set(_filter.copyWith(favoritesOnly: v)),
                ),
              ),
              for (final c in WorkoutCategory.values.where((c) => c != WorkoutCategory.custom))
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: FilterChip(
                    label: Text(c.label),
                    selected: _filter.categories.contains(c),
                    onSelected: (on) => _set(
                      _filter.copyWith(
                        categories: on
                            ? {..._filter.categories, c}
                            : ({..._filter.categories}..remove(c)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} workouts · ${_filter.sort.label}',
                  style: context.text.bodySmall,
                ),
              ),
              if (!_filter.isEmpty)
                TextButton(onPressed: _clearAll, child: const Text('Clear all')),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: _filter.favoritesOnly && favorites.ids(FavoriteKind.workout).isEmpty
                        ? 'No favorite workouts yet'
                        : 'No workouts match',
                    message: 'Try removing a filter or searching for something else.',
                    actionLabel: 'Clear all filters',
                    onAction: _clearAll,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xxl),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) => ContentWidth(
                    child: WorkoutCard(
                      workout: results[i],
                      onTap: () => Nav.push(context, WorkoutDetailScreen(workout: results[i])),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _WorkoutFilterSheet extends StatefulWidget {
  const _WorkoutFilterSheet({required this.initial});

  final WorkoutFilter initial;

  @override
  State<_WorkoutFilterSheet> createState() => _WorkoutFilterSheetState();
}

class _WorkoutFilterSheetState extends State<_WorkoutFilterSheet> {
  late WorkoutFilter _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              children: [
                Text('Filter and sort', style: context.text.titleLarge),
                const SectionHeader(title: 'Sort by'),
                ChoiceChips<WorkoutSort>(
                  options: WorkoutSort.values,
                  selected: _f.sort,
                  labelOf: (s) => s.label,
                  onSelected: (s) => setState(() => _f = _f.copyWith(sort: s)),
                ),
                const SectionHeader(title: 'Duration'),
                MultiChoiceChips(
                  options: DurationBucket.values,
                  selected: _f.durations,
                  labelOf: (d) => d.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(durations: s)),
                ),
                const SectionHeader(title: 'Level'),
                MultiChoiceChips(
                  options: Difficulty.values,
                  selected: _f.difficulties,
                  labelOf: (d) => d.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(difficulties: s)),
                ),
                const SectionHeader(title: 'Equipment'),
                MultiChoiceChips(
                  options: EquipmentChoice.values,
                  selected: _f.equipment,
                  labelOf: (e) => e.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(equipment: s)),
                ),
                const SectionHeader(title: 'Category'),
                MultiChoiceChips(
                  options: WorkoutCategory.values
                      .where((c) => c != WorkoutCategory.custom)
                      .toList(),
                  selected: _f.categories,
                  labelOf: (c) => c.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(categories: s)),
                ),
                const SectionHeader(title: 'More'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Low impact only'),
                  value: _f.lowImpactOnly,
                  onChanged: (v) => setState(() => _f = _f.copyWith(lowImpactOnly: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Favorites only'),
                  value: _f.favoritesOnly,
                  onChanged: (v) => setState(() => _f = _f.copyWith(favoritesOnly: v)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _f = _f.clearFilters()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _f),
                      child: const Text('Show results'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final favorites = context.watch<FavoritesController>();
    final workouts = catalog.workoutsByIds(favorites.ids(FavoriteKind.workout));
    final exercises = catalog.exercisesByIds(favorites.ids(FavoriteKind.exercise));
    if (workouts.isEmpty && exercises.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'No favorites yet',
          message: 'Tap the heart on any workout or exercise to save it here.',
          actionLabel: 'Browse workouts',
          onAction: () =>
              ShellNavigator.of(context).goTo(ShellTab.workouts, section: WorkoutsSection.workouts),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
      children: [
        if (workouts.isNotEmpty) ...[
          SectionHeader(title: 'Workouts (${workouts.length})'),
          for (final w in workouts)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ContentWidth(
                child: WorkoutCard(
                  workout: w,
                  onTap: () => Nav.push(context, WorkoutDetailScreen(workout: w)),
                ),
              ),
            ),
        ],
        if (exercises.isNotEmpty) ...[
          SectionHeader(title: 'Exercises (${exercises.length})'),
          for (final e in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ContentWidth(
                child: ExerciseTile(
                  exercise: e,
                  onTap: () => Nav.push(context, ExerciseDetailScreen(exercise: e)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MyWorkoutsView extends StatelessWidget {
  const _MyWorkoutsView();

  void _create(BuildContext context) => Nav.push(
    context,
    WorkoutBuilderScreen(initial: context.read<CustomWorkoutController>().newDraft(), isNew: true),
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CustomWorkoutController>();
    final workouts = controller.workouts;
    if (workouts.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.edit_note_rounded,
          title: 'Build your own workout',
          message:
              'Pick exercises from the library, set reps or time, rest and '
              'rounds, and save it to use any time.',
          actionLabel: 'Create a workout',
          onAction: () => _create(context),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xxl),
      children: [
        FilledButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create a workout'),
        ),
        const SizedBox(height: Space.md),
        for (final custom in workouts)
          if (controller.playable(custom.id) case final workout?)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: ContentWidth(
                child: WorkoutCard(
                  workout: workout,
                  subtitle: custom.description.isEmpty
                      ? '${custom.steps.length} exercises'
                      : custom.description,
                  onTap: () => Nav.push(context, WorkoutDetailScreen(workout: workout)),
                ),
              ),
            ),
      ],
    );
  }
}
