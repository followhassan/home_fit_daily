import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_profile.dart';
import '../../state/profile_controller.dart';
import 'preference_fields.dart';

/// Edit every preference collected during onboarding.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late UserProfile _p = context.read<ProfileController>().profile;
  late final _name = TextEditingController(text: _p.displayName);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ProfileController>().update(
        (_) => _p.copyWith(displayName: _name.text.trim()),
      );
      if (mounted) {
        Navigator.of(context).pop();
        showMessage(context, 'Preferences saved');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & preferences'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
            children: [
              const SectionHeader(title: 'Display name (optional)'),
              TextField(
                controller: _name,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Used only for greetings'),
              ),
              const SectionHeader(title: 'Experience'),
              OptionList<Difficulty>(
                options: Difficulty.values,
                selected: _p.experienceLevel,
                title: (d) => d.label,
                subtitle: experienceDescription,
                onSelected: (d) => setState(() => _p = _p.copyWith(experienceLevel: d)),
              ),
              const SectionHeader(title: 'Main goal'),
              OptionList<FitnessGoal>(
                options: FitnessGoal.values,
                selected: _p.primaryGoal,
                title: (g) => g.label,
                subtitle: goalDescription,
                onSelected: (g) => setState(() => _p = _p.copyWith(primaryGoal: g)),
              ),
              const SectionHeader(title: 'Preferred workout length'),
              DurationPicker(
                value: _p.preferredDurationMinutes,
                onChanged: (m) => setState(() => _p = _p.copyWith(preferredDurationMinutes: m)),
              ),
              const SectionHeader(title: 'Workout days'),
              DaysPicker(
                days: _p.preferredDays,
                onChanged: (d) => setState(() => _p = _p.copyWith(preferredDays: d)),
              ),
              const SizedBox(height: Space.md),
              NumberStepper(
                label: 'Weekly target (workouts)',
                value: _p.weeklyGoal,
                min: 1,
                max: 7,
                onChanged: (g) => setState(() => _p = _p.copyWith(weeklyGoal: g)),
              ),
              const SectionHeader(title: 'Equipment you have'),
              EquipmentPicker(
                selected: _p.availableEquipment,
                onChanged: (e) => setState(() => _p = _p.copyWith(availableEquipment: e)),
              ),
              const SectionHeader(title: 'Impact'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prefer low-impact workouts'),
                subtitle: const Text('Suggestions avoid jumping and hopping'),
                value: _p.lowImpactPreference,
                onChanged: (v) => setState(() => _p = _p.copyWith(lowImpactPreference: v)),
              ),
              const SectionHeader(title: 'Units'),
              UnitsPicker(
                value: _p.unitSystem,
                onChanged: (u) => setState(() => _p = _p.copyWith(unitSystem: u)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
