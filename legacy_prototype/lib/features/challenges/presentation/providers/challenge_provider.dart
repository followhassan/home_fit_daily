import 'package:flutter/foundation.dart';

import '../../data/models/challenge_model.dart';
import '../../data/repositories/challenge_repository.dart';

class ChallengeProvider extends ChangeNotifier {
  ChallengeProvider(this._repository);

  final ChallengeRepository _repository;

  List<ChallengeModel> _challenges = [];
  bool _loading = true;

  List<ChallengeModel> get challenges => _challenges;
  List<ChallengeModel> get dailyChallenges =>
      _challenges.where((c) => c.type == 'daily').toList();
  List<ChallengeModel> get weeklyChallenges =>
      _challenges.where((c) => c.type == 'weekly').toList();
  bool get isLoading => _loading;

  Future<void> loadChallenges() async {
    _loading = true;
    _challenges = await _repository.getChallenges();
    _loading = false;
    notifyListeners();
  }

  Future<void> updateProgress({
    required int todayWorkouts,
    required int todayMinutes,
    required int todayCalories,
    required int weeklyWorkouts,
  }) async {
    await _repository.updateChallengeProgress(
      workouts: todayWorkouts,
      minutes: todayMinutes,
      calories: todayCalories,
      weeklyWorkouts: weeklyWorkouts,
    );
    await loadChallenges();
  }

  Future<void> reset() async {
    await _repository.resetChallenges();
    await loadChallenges();
  }
}
