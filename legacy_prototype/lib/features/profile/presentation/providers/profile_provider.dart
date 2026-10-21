import 'package:flutter/foundation.dart';

import '../../data/models/user_profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../../core/utils/bmi_calculator.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository);

  final ProfileRepository _repository;

  UserProfileModel? _profile;
  bool _loading = true;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _loading;

  double get bmi {
    if (_profile == null) return 0;
    return BmiCalculator.calculate(_profile!.weight, _profile!.height);
  }

  String get bmiCategory => BmiCalculator.category(bmi);

  Future<void> loadProfile() async {
    if (_loading && _profile != null) return;
    _loading = true;
    _profile = await _repository.getProfile();
    _loading = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    int? age,
    String? gender,
    double? weight,
    double? height,
    double? goalWeight,
    String? fitnessGoal,
  }) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      name: name,
      age: age,
      gender: gender,
      weight: weight,
      height: height,
      goalWeight: goalWeight,
      fitnessGoal: fitnessGoal,
    );
    await _repository.saveProfile(_profile!);
    notifyListeners();
  }

  Future<void> recordWorkout(int calories) async {
    await _repository.updateStreak(DateTime.now());
    await _repository.addWorkoutStats(calories);
    await loadProfile();
  }
}
