import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_profile.dart';

/// Option lists with short explanations, shared by onboarding and the
/// preferences screen.
class OptionList<T> extends StatelessWidget {
  const OptionList({
    super.key,
    required this.options,
    required this.selected,
    required this.title,
    required this.onSelected,
    this.subtitle,
  });

  final List<T> options;
  final T selected;
  final String Function(T) title;
  final String Function(T)? subtitle;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: selected,
      onChanged: (v) {
        if (v != null) onSelected(v);
      },
      child: Column(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: AppCard(
                padding: EdgeInsets.zero,
                onTap: () => onSelected(option),
                child: RadioListTile<T>(
                  value: option,
                  title: Text(title(option)),
                  subtitle: subtitle == null ? null : Text(subtitle!(option)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String experienceDescription(Difficulty d) => switch (d) {
  Difficulty.beginner => 'New to exercise or returning after a break',
  Difficulty.intermediate => 'Exercising fairly regularly; comfortable with push-ups and squats',
  Difficulty.advanced => 'Training often and comfortable with jumping and harder variations',
};

String goalDescription(FitnessGoal g) => switch (g) {
  FitnessGoal.consistency => 'Make movement a regular habit',
  FitnessGoal.strength => 'Get stronger with bodyweight training',
  FitnessGoal.endurance => 'Build stamina with cardio-style sessions',
  FitnessGoal.mobility => 'Move more freely and feel less stiff',
};

class DurationPicker extends StatelessWidget {
  const DurationPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceChips<int>(
    options: UserProfile.durationOptions,
    selected: value,
    labelOf: (m) => '$m min',
    onSelected: onChanged,
  );
}

class DaysPicker extends StatelessWidget {
  const DaysPicker({super.key, required this.days, required this.onChanged});

  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => MultiChoiceChips<int>(
    options: const [1, 2, 3, 4, 5, 6, 7],
    selected: days,
    labelOf: Formatters.weekdayShort,
    onChanged: onChanged,
  );
}

class EquipmentPicker extends StatelessWidget {
  const EquipmentPicker({super.key, required this.selected, required this.onChanged});

  final Set<Equipment> selected;
  final ValueChanged<Set<Equipment>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilterChip(
        label: const Text('No equipment'),
        selected: selected.isEmpty,
        onSelected: (_) => onChanged(const {}),
      ),
      const SizedBox(height: Space.sm),
      MultiChoiceChips<Equipment>(
        options: Equipment.values,
        selected: selected,
        labelOf: (e) => e.label,
        onChanged: onChanged,
      ),
      const SizedBox(height: Space.sm),
      Text(
        'Most workouts need no equipment. A mat is never required – a carpet or folded towel works.',
        style: context.text.bodySmall,
      ),
    ],
  );
}

class UnitsPicker extends StatelessWidget {
  const UnitsPicker({super.key, required this.value, required this.onChanged});

  final UnitSystem value;
  final ValueChanged<UnitSystem> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<UnitSystem>(
    segments: [for (final u in UnitSystem.values) ButtonSegment(value: u, label: Text(u.label))],
    selected: {value},
    showSelectedIcon: false,
    onSelectionChanged: (s) => onChanged(s.first),
  );
}
