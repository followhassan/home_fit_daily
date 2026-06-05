import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading || provider.profile == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.premiumPink),
            ),
          );
        }

        final user = provider.profile!;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                title: const Text('Profile'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _ProfileHeader(
                        name: user.name,
                        onEdit: () => _showEditDialog(context, provider, user),
                      ),
                      const SizedBox(height: 20),
                      GradientCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4FA3), Color(0xFF1A1A1A)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BmiDisplay(
                              bmi: provider.bmi,
                              category: provider.bmiCategory,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Total Workouts',
                              value: '${user.totalWorkouts}',
                              icon: Icons.fitness_center,
                              delay: 100.ms,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Total Calories',
                              value: '${user.totalCalories}',
                              icon: Icons.local_fire_department,
                              subtitle: 'kcal',
                              delay: 200.ms,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _ProfileInfoTile(
                        icon: Icons.person,
                        label: 'Age',
                        value: '${user.age} years',
                      ),
                      _ProfileInfoTile(
                        icon: Icons.wc,
                        label: 'Gender',
                        value: user.gender,
                      ),
                      _ProfileInfoTile(
                        icon: Icons.monitor_weight,
                        label: 'Weight',
                        value: '${user.weight} kg',
                      ),
                      _ProfileInfoTile(
                        icon: Icons.height,
                        label: 'Height',
                        value: '${user.height} cm',
                      ),
                      _ProfileInfoTile(
                        icon: Icons.flag,
                        label: 'Goal Weight',
                        value: '${user.goalWeight} kg',
                      ),
                      _ProfileInfoTile(
                        icon: Icons.track_changes,
                        label: 'Fitness Goal',
                        value: user.fitnessGoal,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.premiumPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: AppColors.premiumPink,
                          ),
                        ),
                        title: const Text('Achievements'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AchievementsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEditDialog(context, provider, user),
            backgroundColor: AppColors.premiumPink,
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    ProfileProvider provider,
    dynamic user,
  ) {
    final nameController = TextEditingController(text: user.name);
    final ageController = TextEditingController(text: '${user.age}');
    final weightController = TextEditingController(text: '${user.weight}');
    final heightController = TextEditingController(text: '${user.height}');
    final goalWeightController =
        TextEditingController(text: '${user.goalWeight}');
    final goalController = TextEditingController(text: user.fitnessGoal);
    String gender = user.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => gender = v ?? gender,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: goalWeightController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Goal Weight (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: goalController,
                decoration:
                    const InputDecoration(labelText: 'Fitness Goal'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await provider.updateProfile(
                      name: nameController.text,
                      age: int.tryParse(ageController.text) ?? user.age,
                      gender: gender,
                      weight: double.tryParse(weightController.text) ??
                          user.weight,
                      height: double.tryParse(heightController.text) ??
                          user.height,
                      goalWeight:
                          double.tryParse(goalWeightController.text) ??
                              user.goalWeight,
                      fitnessGoal: goalController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.onEdit});

  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.premiumPink.withValues(alpha: 0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                'Fitness Enthusiast',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BmiDisplay extends StatelessWidget {
  const _BmiDisplay({required this.bmi, required this.category});

  final double bmi;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'BMI',
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Text(
          bmi.toStringAsFixed(1),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          category,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GradientCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        animate: false,
        child: Row(
          children: [
            Icon(icon, color: AppColors.premiumPink, size: 20),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
