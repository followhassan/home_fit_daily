import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/data_export_import.dart';
import '../../../achievements/presentation/providers/achievement_provider.dart';
import '../../../challenges/presentation/providers/challenge_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../workout/presentation/providers/workout_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SettingsSection(
                title: 'Appearance',
                children: [
                  SwitchListTile(
                    title: const Text(AppStrings.darkMode),
                    subtitle: const Text('Toggle dark/light theme'),
                    value: settings.isDarkMode,
                    activeThumbColor: AppColors.premiumPink,
                    onChanged: settings.setDarkMode,
                  ),
                ],
              ),
              _SettingsSection(
                title: 'Notifications',
                children: [
                  SwitchListTile(
                    title: const Text(AppStrings.notifications),
                    subtitle: const Text(AppStrings.dailyReminder),
                    value: settings.notificationsEnabled,
                    activeThumbColor: AppColors.premiumPink,
                    onChanged: settings.setNotifications,
                  ),
                ],
              ),
              _SettingsSection(
                title: 'Data',
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload, color: AppColors.premiumPink),
                    title: const Text(AppStrings.exportData),
                    subtitle: const Text('Copy your data to clipboard'),
                    onTap: () => _exportData(context),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.download, color: AppColors.premiumPink),
                    title: const Text(AppStrings.importData),
                    subtitle: const Text('Paste JSON data to restore'),
                    onTap: () => _importData(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.redAccent),
                    title: const Text(AppStrings.resetProgress),
                    subtitle: const Text('Clear all workout data'),
                    onTap: () => _confirmReset(context),
                  ),
                ],
              ),
              _SettingsSection(
                title: 'About',
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('HomeFit – Home Workout Fitness'),
                    subtitle: Text('Version 1.0.0 • Fully Offline'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final profile = context.read<ProfileProvider>().profile;
    final workout = context.read<WorkoutProvider>();
    final achievements = context.read<AchievementProvider>();
    final challenges = context.read<ChallengeProvider>();

    await workout.loadData();
    await achievements.loadAchievements();
    await challenges.loadChallenges();

    final json = DataExportImport.export(
      profile: profile,
      history: workout.history,
      achievements: achievements.achievements,
      challenges: challenges.challenges,
      favorites: workout.favorites,
    );

    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data copied to clipboard')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste JSON data here...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    final data = DataExportImport.parse(controller.text);
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid JSON data')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import parsed successfully. Restart app to apply.'),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
          'This will delete all workout history, achievements, and challenges. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<SettingsProvider>().resetProgress();
    if (!context.mounted) return;
    await context.read<ProfileProvider>().loadProfile();
    if (!context.mounted) return;
    await context.read<WorkoutProvider>().loadData();
    if (!context.mounted) return;
    await context.read<AchievementProvider>().loadAchievements();
    if (!context.mounted) return;
    await context.read<ChallengeProvider>().loadChallenges();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset successfully')),
      );
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.premiumPink,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkGrey,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
