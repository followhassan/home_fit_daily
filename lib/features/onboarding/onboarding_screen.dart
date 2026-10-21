import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_button.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_profile.dart';
import '../../state/measurement_controller.dart';
import '../../state/profile_controller.dart';
import '../settings/preference_fields.dart';

/// A short, skippable setup. Every question is optional and can be changed
/// later in Settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 8;
  int _step = 0;
  late UserProfile _p = context.read<ProfileController>().profile;
  final _name = TextEditingController();
  final _weight = TextEditingController();
  String? _weightError;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _name.text = _p.displayName;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 6 && !_validateWeight()) return;
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  bool _validateWeight() {
    final text = _weight.text.trim();
    if (text.isEmpty) {
      setState(() => _weightError = null);
      return true;
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    try {
      if (value == null) {
        throw const MeasurementValidationException('Enter a number, or leave it empty.');
      }
      MeasurementController.toCanonical(MeasurementType.weight, value, _p.unitSystem);
      setState(() => _weightError = null);
      return true;
    } on MeasurementValidationException catch (e) {
      setState(() => _weightError = e.message);
      return false;
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final profileController = context.read<ProfileController>();
    final measurements = context.read<MeasurementController>();
    try {
      final days = _p.preferredDays;
      final profile = _p.copyWith(
        displayName: _name.text.trim(),
        weeklyGoal: days.isEmpty ? 3 : days.length,
      );
      final weightText = _weight.text.trim();
      if (weightText.isNotEmpty) {
        await measurements.add(
          type: MeasurementType.weight,
          value: double.parse(weightText.replaceAll(',', '.')),
          unit: profile.unitSystem,
          note: 'Starting weight',
        );
      }
      await profileController.completeOnboarding(profile);
    } catch (_) {
      if (mounted) {
        setState(() => _finishing = false);
        showMessage(context, 'Could not save your setup. Please try again.');
      }
    }
  }

  Future<void> _skipAll() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await context.read<ProfileController>().skipOnboarding();
    } catch (_) {
      if (mounted) {
        setState(() => _finishing = false);
        showMessage(context, 'Could not continue. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: ContentWidth(
            maxWidth: 560,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.sm, 0),
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: Space.tapTarget),
                      Expanded(
                        child: _step == 0
                            ? const SizedBox.shrink()
                            : Semantics(
                                label: 'Step $_step of ${_stepCount - 1}',
                                child: LinearProgressIndicator(
                                  value: _step / (_stepCount - 1),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                      ),
                      TextButton(
                        onPressed: _finishing ? null : _skipAll,
                        child: const Text('Skip setup'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
                    child: _buildStep(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
                  child: PremiumButton(
                    label: _step == 0
                        ? 'Set up in about a minute'
                        : _step == _stepCount - 1
                        ? 'Get started'
                        : 'Continue',
                    icon: _step == _stepCount - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    width: double.infinity,
                    loading: _finishing,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            subtitle,
            style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
          ),
        ],
      ],
    ),
  );

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.fitness_center_rounded, size: 44, color: AppColors.white),
              ),
            ),
            const SizedBox(height: Space.xl),
            _title(
              context,
              'Welcome to ${AppConstants.appName}',
              'Home workouts and a fitness guide in your pocket.',
            ),
            const _Point(
              icon: Icons.wifi_off_rounded,
              title: 'Works completely offline',
              text: 'No account, no sign-in and no internet connection needed.',
            ),
            const _Point(
              icon: Icons.inventory_2_outlined,
              title: 'Everything is included',
              text: 'Exercises with demonstrations, ready-made workouts, 4-week plans and a guide.',
            ),
            const _Point(
              icon: Icons.phone_android_rounded,
              title: 'Your progress stays on this device',
              text: 'Nothing is uploaded. You can export a backup whenever you like.',
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context, 'What should we call you?', 'Optional – used only for greetings.'),
            TextField(
              controller: _name,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _next(),
              decoration: const InputDecoration(labelText: 'Display name (optional)'),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(
              context,
              'Your experience',
              'This helps suggest workouts at a comfortable level.',
            ),
            OptionList<Difficulty>(
              options: Difficulty.values,
              selected: _p.experienceLevel,
              title: (d) => d.label,
              subtitle: experienceDescription,
              onSelected: (d) => setState(() => _p = _p.copyWith(experienceLevel: d)),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context, 'Your main goal'),
            OptionList<FitnessGoal>(
              options: FitnessGoal.values,
              selected: _p.primaryGoal,
              title: (g) => g.label,
              subtitle: goalDescription,
              onSelected: (g) => setState(() => _p = _p.copyWith(primaryGoal: g)),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(
              context,
              'Your schedule',
              'How long, and on which days, would you like to work out?',
            ),
            Text('Workout length', style: context.text.titleMedium),
            const SizedBox(height: Space.sm),
            DurationPicker(
              value: _p.preferredDurationMinutes,
              onChanged: (m) => setState(() => _p = _p.copyWith(preferredDurationMinutes: m)),
            ),
            const SizedBox(height: Space.xl),
            Text('Workout days', style: context.text.titleMedium),
            const SizedBox(height: Space.sm),
            DaysPicker(
              days: _p.preferredDays,
              onChanged: (d) => setState(() => _p = _p.copyWith(preferredDays: d)),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Your weekly target will be ${_p.preferredDays.isEmpty ? 3 : _p.preferredDays.length} '
              'workouts. Rest days in between help you recover.',
              style: context.text.bodySmall,
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context, 'Equipment', 'Choose anything you have at home.'),
            EquipmentPicker(
              selected: _p.availableEquipment,
              onChanged: (e) => setState(() => _p = _p.copyWith(availableEquipment: e)),
            ),
            const SizedBox(height: Space.xl),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prefer low-impact workouts'),
              subtitle: const Text('No jumping – kinder to joints and neighbours'),
              value: _p.lowImpactPreference,
              onChanged: (v) => setState(() => _p = _p.copyWith(lowImpactPreference: v)),
            ),
          ],
        );
      case 6:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context, 'Units', 'Used for optional body measurements.'),
            UnitsPicker(
              value: _p.unitSystem,
              onChanged: (u) => setState(() {
                _p = _p.copyWith(unitSystem: u);
                _weightError = null;
              }),
            ),
            const SizedBox(height: Space.xl),
            Text('Starting weight (optional)', style: context.text.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'Only if you want to track it. There is no weight goal, and you can '
              'add or remove entries any time.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Weight',
                suffixText: Units.weightUnit(_p.unitSystem),
                errorText: _weightError,
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(context, 'Before you start'),
            const _Point(
              icon: Icons.health_and_safety_outlined,
              title: 'Listen to your body',
              text:
                  'Stop and rest if you feel chest pain, dizziness, unusual breathlessness '
                  'or sharp pain. Every exercise has an easier option.',
            ),
            const _Point(
              icon: Icons.medical_information_outlined,
              title: 'Check if you are unsure',
              text:
                  'If a health condition, injury or pregnancy affects how you exercise, '
                  'ask a doctor or qualified professional what suits you.',
            ),
            const _Point(
              icon: Icons.menu_book_outlined,
              title: 'General guidance',
              text:
                  'HomeFit offers general fitness information, not medical advice. You '
                  'can change any of your answers later in Settings.',
            ),
          ],
        );
    }
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: AppColors.premiumPink.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Space.radiusSm),
          ),
          child: Icon(icon, color: context.palette.accentInk),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(text, style: context.text.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
