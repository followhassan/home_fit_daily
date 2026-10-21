import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import '../../domain/filters.dart';
import 'exercise_detail_screen.dart';

/// Searchable, filterable exercise list. Used as a tab in Workouts and as a
/// picker in the workout builder (when [onPick] is set).
class ExerciseLibraryView extends StatefulWidget {
  const ExerciseLibraryView({super.key, this.onPick});

  /// When set, tapping an exercise returns it instead of opening details.
  final ValueChanged<Exercise>? onPick;

  @override
  State<ExerciseLibraryView> createState() => _ExerciseLibraryViewState();
}

class _ExerciseLibraryViewState extends State<ExerciseLibraryView>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  ExerciseFilter _filter = const ExerciseFilter();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(ExerciseFilter filter) => setState(() => _filter = filter);

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ExerciseFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExerciseFilterSheet(initial: _filter),
    );
    if (result != null) _setFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final catalog = context.read<Catalog>();
    final results = catalog.exercises.where(_filter.matches).toList();
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
                    hintText: 'Search exercises',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _setFilter(_filter.copyWith(query: ''));
                            },
                          ),
                  ),
                  onChanged: (q) => _setFilter(_filter.copyWith(query: q)),
                ),
              ),
              const SizedBox(width: Space.sm),
              Badge(
                isLabelVisible: _filter.activeCount > 0,
                label: Text('${_filter.activeCount}'),
                child: IconButton.filledTonal(
                  tooltip: 'Filters',
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
              for (final category in ExerciseCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: FilterChip(
                    label: Text(category.label),
                    selected: _filter.categories.contains(category),
                    onSelected: (on) => _setFilter(
                      _filter.copyWith(
                        categories: on
                            ? {..._filter.categories, category}
                            : ({..._filter.categories}..remove(category)),
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
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${results.length} of ${catalog.exercises.length} exercises',
                    style: context.text.bodySmall,
                  ),
                ),
              ),
              if (!_filter.isEmpty)
                TextButton(
                  onPressed: () {
                    _search.clear();
                    _setFilter(const ExerciseFilter());
                  },
                  child: const Text('Clear all'),
                ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No exercises match',
                    message: 'Try a different search word or remove some filters.',
                    actionLabel: 'Clear all filters',
                    onAction: () {
                      _search.clear();
                      _setFilter(const ExerciseFilter());
                    },
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.xxl),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final exercise = results[i];
                    return ContentWidth(
                      child: ExerciseTile(
                        exercise: exercise,
                        trailing: widget.onPick == null
                            ? null
                            : Icon(
                                Icons.add_circle_outline_rounded,
                                color: context.palette.accentInk,
                              ),
                        onTap: () => widget.onPick != null
                            ? widget.onPick!(exercise)
                            : Nav.push(context, ExerciseDetailScreen(exercise: exercise)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExerciseFilterSheet extends StatefulWidget {
  const _ExerciseFilterSheet({required this.initial});

  final ExerciseFilter initial;

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  late ExerciseFilter _f = widget.initial;

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
                Text('Filter exercises', style: context.text.titleLarge),
                const SectionHeader(title: 'Category'),
                MultiChoiceChips(
                  options: ExerciseCategory.values,
                  selected: _f.categories,
                  labelOf: (c) => c.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(categories: s)),
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
                const SectionHeader(title: 'Muscle group'),
                MultiChoiceChips(
                  options: MuscleGroup.values,
                  selected: _f.muscles,
                  labelOf: (m) => m.label,
                  onChanged: (s) => setState(() => _f = _f.copyWith(muscles: s)),
                ),
                const SectionHeader(title: 'Impact'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Low impact only'),
                  subtitle: const Text('No jumping or hopping'),
                  value: _f.lowImpactOnly,
                  onChanged: (v) => setState(() => _f = _f.copyWith(lowImpactOnly: v)),
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
