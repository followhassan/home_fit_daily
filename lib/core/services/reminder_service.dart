import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/app_settings.dart';

/// Schedules local workout reminders. No push service is involved.
abstract interface class ReminderService {
  Future<void> init();

  /// Asks the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Whether notifications are currently allowed, without prompting.
  Future<bool> hasPermission();

  /// Replaces every scheduled reminder with [preferences].
  Future<void> apply(ReminderPreferences preferences);

  Future<void> cancelAll();

  /// Payloads of reminder notifications the user tapped.
  Stream<String> get taps;

  /// Payload of the notification that launched the app, if any.
  Future<String?> takeLaunchPayload();
}

/// [ReminderService] using `flutter_local_notifications`.
///
/// One weekly notification is scheduled per selected weekday, matched on
/// day-of-week and local time, so daylight-saving changes are handled by
/// the OS scheduler. The device time zone is read at startup and reminders
/// are re-applied, which also covers time-zone changes between launches.
/// Inexact scheduling is used, so no exact-alarm permission is needed;
/// reminders may arrive a few minutes late and the OS (battery savers,
/// focus modes, force-stopping the app) may delay or suppress them.
class LocalReminderService implements ReminderService {
  LocalReminderService();

  static const _channelId = 'workout_reminders';
  static const _baseId = 1000;

  /// ID used by the earlier prototype's daily reminder.
  static const _legacyReminderId = 0;
  static const homePayload = 'open:home';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController.broadcast();
  bool _initialized = false;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) => _taps.add(response.payload ?? homePayload),
    );
    _initialized = true;
    // The prototype scheduled an exact daily alarm with ID 0; remove it so
    // only reminders the user controls remain.
    await _plugin.cancel(_legacyReminderId);
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } catch (e) {
      debugPrint('Could not read device time zone: $e');
    }
    // Fallback: any zone with the current UTC offset.
    final offset = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(location).timeZoneOffset.inMilliseconds == offset) {
        tz.setLocalLocation(location);
        return;
      }
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    try {
      if (_android != null) {
        return await _android!.requestNotificationsPermission() ?? false;
      }
      if (_ios != null) {
        return await _ios!.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  @override
  Future<bool> hasPermission() async {
    try {
      if (_android != null) {
        return await _android!.areNotificationsEnabled() ?? false;
      }
      if (_ios != null) {
        return (await _ios!.checkPermissions())?.isEnabled ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
    return false;
  }

  @override
  Future<void> apply(ReminderPreferences preferences) async {
    await cancelAll();
    if (!preferences.enabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Workout reminders',
        channelDescription: 'Optional reminders on the days you choose',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final weekday in preferences.days) {
      await _plugin.zonedSchedule(
        _baseId + weekday,
        'Time to move',
        'Your workout is ready whenever you are.',
        _next(weekday, preferences.hour, preferences.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: homePayload,
      );
    }
  }

  tz.TZDateTime _next(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day + 1,
        hour,
        minute,
      );
    }
    return scheduled;
  }

  @override
  Future<void> cancelAll() async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_baseId + weekday);
    }
  }

  @override
  Future<String?> takeLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        return details!.notificationResponse?.payload ?? homePayload;
      }
    } catch (e) {
      debugPrint('Could not read notification launch details: $e');
    }
    return null;
  }
}
