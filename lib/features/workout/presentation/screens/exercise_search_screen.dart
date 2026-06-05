import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/exercise_icon_widget.dart';
import '../providers/workout_provider.dart';
import 'exercise_detail_screen.dart';

class ExerciseSearchScreen extends StatefulWidget {
  const ExerciseSearchScreen({super.key, this.showFavoritesOnly = false});

  final bool showFavoritesOnly;

  @override
  State<ExerciseSearchScreen> createState() => _ExerciseSearchScreenState();
}

class _ExerciseSearchScreenState extends State<ExerciseSearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showFavoritesOnly ? 'Favorites' : 'Search Exercises'),
      ),
      body: Consumer<WorkoutProvider>(
        builder: (context, provider, _) {
          var exercises = provider.filteredExercises;
          if (widget.showFavoritesOnly) {
            exercises = exercises
                .where((e) => provider.isFavorite(e.id))
                .toList();
          }

          return Column(
            children: [
              if (!widget.showFavoritesOnly) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: provider.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'Search exercises...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.categories.length,
                    itemBuilder: (context, index) {
                      final cat = provider.categories[index];
                      final isSelected = provider.selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => provider.setCategory(cat),
                          selectedColor:
                              AppColors.premiumPink.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.premiumPink,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.premiumPink
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              Expanded(
                child: exercises.isEmpty
                    ? Center(
                        child: Text(
                          widget.showFavoritesOnly
                              ? 'No favorites yet'
                              : 'No exercises found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            leading: ExerciseIconWidget(
                              iconName: exercise.iconName,
                              size: 44,
                              animate: false,
                            ),
                            title: Text(exercise.name),
                            subtitle: Text(
                              '${exercise.category} • ${exercise.bodyPart}',
                            ),
                            trailing: Icon(
                              provider.isFavorite(exercise.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: provider.isFavorite(exercise.id)
                                  ? AppColors.premiumPink
                                  : null,
                              size: 20,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseDetailScreen(
                                  exerciseId: exercise.id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
