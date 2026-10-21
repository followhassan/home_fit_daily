import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/app_settings.dart';
import '../../state/settings_controller.dart';
import 'preference_fields.dart';

/// Local workout reminders. Permission is requested only when the user
/// turns reminders on; a refusal is handled without blocking anything.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late ReminderPreferences _prefs = context.read<SettingsController>().settings.reminders;
  bool _busy = false;

  Future<void> _toggle(bool enable) async {
    final settings = context.read<SettingsController>();
    setState(() => _busy = true);
    try {
      if (!enable) {
        await settings.disableReminders();
        if (mounted) showMessage(context, 'Reminders turned off');
      } else {
        if (_prefs.days.isEmpty) {
          showMessage(context, 'Choose at least one day first.');
          return;
        }
        final result = await settings.enableReminders(_prefs);
        if (!mounted) return;
        switch (result) {
          case ReminderResult.scheduled:
            showMessage(context, 'Reminders scheduled');
          case ReminderResult.permissionDenied:
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Notifications are off'),
                content: const Text(
                  'HomeFit is not allowed to show notifications, so reminders '
                  'cannot be delivered. You can allow notifications for HomeFit '
                  'in your device settings and try again. Everything else in the '
                  'app works normally without reminders.',
                ),
                actions: [
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                ],
              ),
            );
          case ReminderResult.failed:
            showMessage(context, 'Reminders could not be scheduled on this device.');
          case ReminderResult.disabled:
            break;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _prefs = context.read<SettingsController>().settings.reminders;
        });
      }
    }
  }

  Future<void> _updateSchedule(ReminderPreferences updated) async {
    setState(() => _prefs = updated.copyWith(enabled: _prefs.enabled));
    if (updated.days.isEmpty) return;
    await context.read<SettingsController>().updateReminderSchedule(_prefs);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final enabled = settings.settings.reminders.enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Workout reminders'),
                subtitle: const Text('A gentle notification on the days you choose'),
                value: enabled,
                onChanged: _busy ? null : _toggle,
              ),
              if (enabled && settings.notificationsBlocked)
                AppCard(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off_outlined, color: context.palette.warning),
                      const SizedBox(width: Space.md),
                      const Expanded(
                        child: Text(
                          'Notifications are currently blocked for HomeFit in your device '
                          'settings, so reminders will not appear.',
                        ),
                      ),
                    ],
                  ),
                ),
              const SectionHeader(title: 'Days'),
              DaysPicker(
                days: _prefs.days,
                onChanged: (d) => _updateSchedule(_prefs.copyWith(days: d)),
              ),
              if (_prefs.days.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    'Choose at least one day.',
                    style: context.text.bodySmall?.copyWith(color: context.palette.error),
                  ),
                ),
              const SectionHeader(title: 'Time'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(Formatters.timeOfDay(_prefs.hour, _prefs.minute)),
                trailing: const Text('Change'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _prefs.hour, minute: _prefs.minute),
                  );
                  if (picked != null) {
                    await _updateSchedule(
                      _prefs.copyWith(hour: picked.hour, minute: picked.minute),
                    );
                  }
                },
              ),
              const SizedBox(height: Space.lg),
              Text(
                'Reminders are local notifications created on this device – no account '
                'or internet connection is involved. They follow your local time, '
                'including daylight-saving changes. Phones can delay or hide '
                'notifications (for example in battery-saving or do-not-disturb '
                'modes), so delivery cannot be guaranteed.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
