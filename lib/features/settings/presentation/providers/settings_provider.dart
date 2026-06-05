import 'package:flutter/foundation.dart';

import '../../../../core/services/hive_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/models/app_settings_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../achievements/data/repositories/achievement_repository.dart';
import '../../../challenges/data/repositories/challenge_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(
    this._repository,
    this._achievementRepository,
    this._challengeRepository,
  );

  final SettingsRepository _repository;
  final AchievementRepository _achievementRepository;
  final ChallengeRepository _challengeRepository;

  AppSettingsModel? _settings;
  bool _onboardingComplete = false;
  bool _loading = true;

  AppSettingsModel? get settings => _settings;
  bool get onboardingComplete => _onboardingComplete;
  bool get isLoading => _loading;
  bool get isDarkMode => _settings?.darkMode ?? true;
  bool get notificationsEnabled => _settings?.notificationsEnabled ?? true;

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    _settings = await _repository.getSettings();
    _onboardingComplete = await _repository.isOnboardingComplete();
    _loading = false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _settings?.darkMode = value;
    if (_settings != null) await _repository.saveSettings(_settings!);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _settings?.notificationsEnabled = value;
    if (_settings != null) await _repository.saveSettings(_settings!);

    if (value) {
      await NotificationService.instance.scheduleDailyReminder();
    } else {
      await NotificationService.instance.cancelAll();
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _repository.setOnboardingComplete(true);
    _onboardingComplete = true;
    notifyListeners();
  }

  Future<void> resetProgress() async {
    await HiveService.instance.clearAll();
    await _achievementRepository.resetAchievements();
    await _challengeRepository.resetChallenges();
    _settings = AppSettingsModel();
    await _repository.saveSettings(_settings!);
    notifyListeners();
  }
}
