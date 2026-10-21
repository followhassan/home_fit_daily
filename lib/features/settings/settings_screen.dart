import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../state/data_controller.dart';
import '../../state/settings_controller.dart';
import 'backup_screen.dart';
import 'info_screens.dart';
import 'preferences_screen.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = settings.settings;
    final data = context.watch<DataController>();

    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.xs),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: context.text.labelLarge?.copyWith(color: context.palette.accentInk),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            header('You'),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile & preferences'),
              subtitle: const Text('Name, level, goal, duration, days, equipment, units'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Nav.push(context, const PreferencesScreen()),
            ),
            header('During workouts'),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Sounds'),
              subtitle: const Text('Countdown and start tones'),
              value: s.soundEnabled,
              onChanged: settings.setSound,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Vibration'),
              subtitle: const Text('Haptic cues at the start of each exercise and rest'),
              value: s.vibrationEnabled,
              onChanged: settings.setVibration,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              title: const Text('Keep screen on'),
              subtitle: const Text('Only while a workout is running, not when paused'),
              value: s.keepScreenAwake,
              onChanged: settings.setKeepScreenAwake,
            ),
            header('Reminders'),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Workout reminders'),
              subtitle: Text(
                s.reminders.enabled
                    ? '${s.reminders.days.length} days a week at '
                          '${Formatters.timeOfDay(s.reminders.hour, s.reminders.minute)}'
                          '${settings.notificationsBlocked ? ' · notifications blocked' : ''}'
                    : 'Off',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Nav.push(context, const RemindersScreen()),
            ),
            header('Appearance'),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Theme'),
              subtitle: Text(s.theme.label),
              onTap: () async {
                final choice = await showDialog<ThemePreference>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: const Text('Theme'),
                    children: [
                      RadioGroup<ThemePreference>(
                        groupValue: s.theme,
                        onChanged: (v) => Navigator.pop(context, v),
                        child: Column(
                          children: [
                            for (final t in ThemePreference.values)
                              RadioListTile<ThemePreference>(value: t, title: Text(t.label)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                if (choice != null) await settings.setTheme(choice);
              },
            ),
            header('Your data'),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('Backup & restore'),
              subtitle: const Text('Export or import a backup file'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Nav.push(context, const BackupScreen()),
            ),
            if (data.unreadableRecordCount > 0)
              ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: context.palette.warning),
                title: const Text('Some saved records could not be read'),
                subtitle: Text(
                  '${data.unreadableRecordCount} record(s) appear damaged and are hidden. '
                  'Tap to remove them.',
                ),
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Remove unreadable records?',
                    message: 'These records cannot be displayed and will be permanently deleted.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    final removed = await context.read<DataController>().removeUnreadableRecords();
                    if (context.mounted) showMessage(context, 'Removed $removed record(s)');
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset workout progress'),
              subtitle: const Text('Deletes history and plan progress'),
              onTap: data.isBusy ? null : () => _resetProgress(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: context.palette.error),
              title: Text(
                'Delete all personal data',
                style: TextStyle(color: context.palette.error),
              ),
              subtitle: const Text('Erases everything stored by the app on this device'),
              onTap: data.isBusy ? null : () => _deleteAll(context),
            ),
            header('About'),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              onTap: () => Nav.push(context, const InfoScreen(page: InfoPage.privacy)),
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Fitness disclaimer'),
              onTap: () => Nav.push(context, const InfoScreen(page: InfoPage.disclaimer)),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About HomeFit'),
              onTap: () => Nav.push(context, const InfoScreen(page: InfoPage.about)),
            ),
            ListTile(
              leading: const Icon(Icons.copyright_rounded),
              title: const Text('Content credits & licenses'),
              onTap: () => Nav.push(context, const InfoScreen(page: InfoPage.credits)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetProgress(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Reset workout progress?',
      message:
          'This permanently deletes:\n• all workout history and statistics\n'
          '• your plan enrollment and plan progress\n• any unfinished session\n\n'
          'Your profile, settings, favorites, custom workouts, measurements and '
          'reading progress are kept. Consider exporting a backup first.',
      confirmLabel: 'Reset progress',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<DataController>().resetProgress();
      if (context.mounted) showMessage(context, 'Workout progress reset');
    } catch (_) {
      if (context.mounted) showMessage(context, 'Reset failed. Your data was not changed.');
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Delete all personal data?',
      message:
          'This permanently erases everything HomeFit has stored on this device: '
          'profile, settings, history, plans, custom workouts, favorites, '
          'measurements, bookmarks and reading progress. Reminders are cancelled. '
          'Backup files you exported are not affected. This cannot be undone.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final really = await confirmAction(
      context,
      title: 'Are you sure?',
      message: 'All of your HomeFit data on this device will be deleted.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!really || !context.mounted) return;
    try {
      await context.read<DataController>().deleteAllData();
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (_) {
      if (context.mounted) showMessage(context, 'Deletion failed. Your data was not changed.');
    }
  }
}
