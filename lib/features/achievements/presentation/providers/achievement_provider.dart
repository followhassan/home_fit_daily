import 'package:flutter/foundation.dart';

import '../../data/models/achievement_model.dart';
import '../../data/repositories/achievement_repository.dart';
import '../../../profile/data/models/user_profile_model.dart';

class AchievementProvider extends ChangeNotifier {
  AchievementProvider(this._repository);

  final AchievementRepository _repository;

  List<AchievementModel> _achievements = [];
  bool _loading = true;

  List<AchievementModel> get achievements => _achievements;
  List<AchievementModel> get unlocked =>
      _achievements.where((a) => a.isUnlocked).toList();
  bool get isLoading => _loading;

  Future<void> loadAchievements() async {
    _loading = true;
    notifyListeners();
    _achievements = await _repository.getAchievements();
    _loading = false;
    notifyListeners();
  }

  Future<void> checkAchievements(UserProfileModel profile) async {
    await _repository.checkAndUnlock(profile);
    await loadAchievements();
  }

  Future<void> reset() async {
    await _repository.resetAchievements();
    await loadAchievements();
  }
}
