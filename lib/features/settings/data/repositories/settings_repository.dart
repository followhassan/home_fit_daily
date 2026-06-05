import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/hive_service.dart';
import '../models/app_settings_model.dart';

class SettingsRepository {
  Future<AppSettingsModel> getSettings() async {
    final box = HiveService.instance.settingsBox;
    if (box.isEmpty) {
      final settings = AppSettingsModel();
      await box.put('settings', settings);
      return settings;
    }
    return box.get('settings') ?? AppSettingsModel();
  }

  Future<void> saveSettings(AppSettingsModel settings) async {
    await HiveService.instance.settingsBox.put('settings', settings);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.onboardingKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingKey, value);
  }
}
