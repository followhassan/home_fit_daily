import '../data/models/workout.dart';
import 'workout_timeline.dart';

/// Estimated length of a workout.
class DurationEstimate {
  const DurationEstimate({required this.seconds, required this.isApproximate});

  final int seconds;

  /// True when the workout contains repetition-based sets, whose real
  /// duration depends on the user's pace.
  final bool isApproximate;

  int get minutes => seconds <= 0 ? 0 : (seconds / 60).round().clamp(1, 999);

  /// "About 12 min" or "12 min".
  String get label => isApproximate ? 'About $minutes min' : '$minutes min';

  /// Compact form for chips: "~12 min" or "12 min".
  String get shortLabel => isApproximate ? '~$minutes min' : '$minutes min';
}

/// Computes workout duration from its structure.
///
/// Timed segments contribute their exact length. Repetition-based sets use
/// the exercise's assumed pace (`secondsPerRep`, 3 seconds by default), so
/// any workout containing them is labelled approximate. The preparation
/// countdown, rests and switch-sides transitions are included.
abstract final class DurationEstimator {
  static const int fallbackSecondsPerRep = 3;

  static DurationEstimate estimate(
    Workout workout, {
    required int Function(String exerciseId) secondsPerRep,
  }) {
    final timeline = WorkoutTimeline.build(workout);
    var total = 0;
    var approximate = false;
    for (final segment in timeline.segments) {
      if (segment.waitsForUser) {
        approximate = true;
        final reps = segment.repetitions ?? 0;
        total += reps * secondsPerRep(segment.exerciseId!);
      } else {
        total += segment.durationSeconds ?? 0;
      }
    }
    return DurationEstimate(seconds: total, isApproximate: approximate);
  }
}
