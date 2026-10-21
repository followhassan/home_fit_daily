import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/widgets/animated_progress_ring.dart';
import '../../../../core/widgets/exercise_icon_widget.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../providers/workout_provider.dart';
import 'workout_complete_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, required this.planId});

  final String planId;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  WorkoutPlanEntity? _plan;
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  int _totalElapsed = 0;
  bool _isPaused = false;
  bool _isResting = false;
  int _restSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _plan = context.read<WorkoutProvider>().getPlanById(widget.planId);
    if (_plan != null && _plan!.exercises.isNotEmpty) {
      _remainingSeconds = _plan!.exercises[0].durationSeconds;
      _startTimer();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  ExerciseEntity? get _currentExercise =>
      _plan != null && _currentIndex < _plan!.exercises.length
          ? _plan!.exercises[_currentIndex]
          : null;

  double get _progress {
    if (_plan == null || _plan!.exercises.isEmpty) return 0;
    return (_currentIndex + 1) / _plan!.exercises.length;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;

      if (_isResting) {
        if (_restSeconds > 0) {
          setState(() => _restSeconds--);
        } else {
          setState(() => _isResting = false);
        }
        return;
      }

      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _totalElapsed++;
        });
      } else {
        _onExerciseComplete();
      }
    });
  }

  void _onExerciseComplete() {
    if (_plan == null) return;

    final restTime =
        context.read<SettingsProvider>().settings?.restTimerSeconds ?? 30;

    if (_currentIndex < _plan!.exercises.length - 1) {
      setState(() {
        _isResting = true;
        _restSeconds = restTime;
        _currentIndex++;
        _remainingSeconds = _plan!.exercises[_currentIndex].durationSeconds;
      });
    } else {
      _completeWorkout();
    }
  }

  void _skip() {
    if (_plan == null) return;
    if (_currentIndex < _plan!.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _remainingSeconds = _plan!.exercises[_currentIndex].durationSeconds;
        _isResting = false;
      });
    } else {
      _completeWorkout();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _remainingSeconds = _plan!.exercises[_currentIndex].durationSeconds;
        _isResting = false;
      });
    }
  }

  Future<void> _completeWorkout() async {
    _timer?.cancel();
    if (_plan == null) return;

    final calories = _plan!.exercises
        .fold(0, (sum, e) => sum + e.estimatedCalories);

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          planId: _plan!.id,
          planName: _plan!.name,
          durationSeconds: _totalElapsed,
          caloriesBurned: calories,
          exerciseCount: _plan!.exercises.length,
          difficulty: _plan!.difficultyLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_plan == null || _currentExercise == null) {
      return const Scaffold(
        body: Center(child: Text('Workout not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => _showExitDialog(),
                  ),
                  Text(
                    _plan!.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_currentIndex + 1}/${_plan!.exercises.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.premiumPink,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: AppColors.lightGrey,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.premiumPink),
                ),
              ),
              const Spacer(),
              if (_isResting) ...[
                Text(
                  'Rest Time',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                AnimatedProgressRing(
                  progress: 1 - (_restSeconds / 30),
                  size: 160,
                  child: Text(
                    DateHelper.formatDuration(_restSeconds),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _isResting = false;
                    _restSeconds = 0;
                  }),
                  child: const Text('Skip Rest'),
                ),
              ] else ...[
                ExerciseIconWidget(
                  iconName: _currentExercise!.iconName,
                  size: 140,
                ),
                const SizedBox(height: 32),
                Text(
                  _currentExercise!.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentExercise!.bodyPart,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 32),
                AnimatedProgressRing(
                  progress: _currentExercise!.durationSeconds > 0
                      ? 1 -
                          (_remainingSeconds /
                              _currentExercise!.durationSeconds)
                      : 0,
                  size: 160,
                  child: Text(
                    DateHelper.formatDuration(_remainingSeconds),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: Icons.skip_previous,
                    label: AppStrings.previous,
                    onTap: _previous,
                    enabled: _currentIndex > 0,
                  ),
                  _ControlButton(
                    icon: _isPaused ? Icons.play_arrow : Icons.pause,
                    label: _isPaused ? AppStrings.resume : AppStrings.pause,
                    onTap: () => setState(() => _isPaused = !_isPaused),
                    isPrimary: true,
                  ),
                  _ControlButton(
                    icon: Icons.skip_next,
                    label: AppStrings.skipExercise,
                    onTap: _skip,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: AppStrings.completeWorkout,
                onPressed: _completeWorkout,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Workout?'),
        content: const Text('Your progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: isPrimary ? 64 : 48,
            height: isPrimary ? 64 : 48,
            decoration: BoxDecoration(
              gradient: isPrimary ? AppColors.primaryGradient : null,
              color: isPrimary ? null : AppColors.darkGrey,
              shape: BoxShape.circle,
              border: isPrimary
                  ? null
                  : Border.all(color: AppColors.lightGrey),
            ),
            child: Icon(
              icon,
              color: enabled
                  ? AppColors.white
                  : AppColors.textSecondary,
              size: isPrimary ? 32 : 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
