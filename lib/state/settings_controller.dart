import 'package:flutter/material.dart';

import '../core/services/reminder_service.dart';
import '../data/models/app_settings.dart';
import '../data/models/enums.dart';
import '../data/repositories/repositories.dart';

enum ReminderResult { scheduled, disabled, permissionDenied, failed }

/// App settings, including local reminder scheduling.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repo, this._reminders) {
    _settings = _repo.loadOrDefault();
  }

  final SettingsRepository _repo;
  final ReminderService _reminders;
  late AppSettings _settings;
  bool _notificationsBlocked = false;

  AppSettings get settings => _settings;

  /// True when reminders are on but the OS does not allow notifications.
  bool get notificationsBlocked => _notificationsBlocked;

  ThemeMode get themeMode => switch (_settings.theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  Future<void> _save(AppSettings updated) async {
    await _repo.save(updated);
    _settings = updated;
    notifyListeners();
  }

  Future<void> setTheme(ThemePreference theme) => _save(_settings.copyWith(theme: theme));

  Future<void> setSound(bool value) => _save(_settings.copyWith(soundEnabled: value));

  Future<void> setVibration(bool value) => _save(_settings.copyWith(vibrationEnabled: value));

  Future<void> setKeepScreenAwake(bool value) => _save(_settings.copyWith(keepScreenAwake: value));

  /// Turns reminders on with [preferences]. Permission is requested only
  /// now, when the user asks for reminders. A denial leaves reminders off.
  Future<ReminderResult> enableReminders(ReminderPreferences preferences) async {
    final granted = await _reminders.hasPermission() || await _reminders.requestPermission();
    if (!granted) {
      _notificationsBlocked = true;
      await _save(_settings.copyWith(reminders: preferences.copyWith(enabled: false)));
      return ReminderResult.permissionDenied;
    }
    _notificationsBlocked = false;
    final enabled = preferences.copyWith(enabled: true);
    await _save(_settings.copyWith(reminders: enabled));
    try {
      await _reminders.apply(enabled);
      return ReminderResult.scheduled;
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
      return ReminderResult.failed;
    }
  }

  /// Changes days/time. Reschedules only if reminders are on.
  Future<ReminderResult> updateReminderSchedule(ReminderPreferences preferences) async {
    final updated = preferences.copyWith(enabled: _settings.reminders.enabled);
    await _save(_settings.copyWith(reminders: updated));
    if (!updated.enabled) return ReminderResult.disabled;
    try {
      await _reminders.apply(updated);
      return ReminderResult.scheduled;
    } catch (e) {
      debugPrint('Rescheduling reminders failed: $e');
      return ReminderResult.failed;
    }
  }

  Future<void> disableReminders() async {
    await _save(_settings.copyWith(reminders: _settings.reminders.copyWith(enabled: false)));
    _notificationsBlocked = false;
    try {
      await _reminders.cancelAll();
    } catch (e) {
      debugPrint('Cancelling reminders failed: $e');
    }
    notifyListeners();
  }

  /// Startup and post-import reconciliation: re-applies reminders with the
  /// current time zone if (and only if) permission is still granted. Never
  /// prompts for permission.
  Future<void> reconcileReminders() async {
    try {
      if (!_settings.reminders.enabled) {
        await _reminders.cancelAll();
        return;
      }
      if (await _reminders.hasPermission()) {
        _notificationsBlocked = false;
        await _reminders.apply(_settings.reminders);
      } else {
        _notificationsBlocked = true;
      }
    } catch (e) {
      debugPrint('Reconciling reminders failed: $e');
    }
    notifyListeners();
  }

  void reload() {
    _settings = _repo.loadOrDefault();
    notifyListeners();
  }
}
