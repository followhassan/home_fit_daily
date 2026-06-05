import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPageData(
      title: AppStrings.welcome,
      subtitle: 'Your personal home fitness companion',
      icon: Icons.fitness_center_rounded,
      gradient: [Color(0xFFFF4FA3), Color(0xFF0D0D0D)],
    ),
    _OnboardingPageData(
      title: AppStrings.homeWorkout,
      subtitle: 'No gym? No problem. Train anywhere, anytime.',
      icon: Icons.home_rounded,
      gradient: [Color(0xFFFF1F8F), Color(0xFF1A1A1A)],
    ),
    _OnboardingPageData(
      title: AppStrings.trackProgress,
      subtitle: 'Monitor streaks, calories, and unlock achievements.',
      icon: Icons.trending_up_rounded,
      gradient: [Color(0xFFFF4FA3), Color(0xFF2A2A2A)],
    ),
    _OnboardingPageData(
      title: AppStrings.startJourney,
      subtitle: 'Transform your body from the comfort of home.',
      icon: Icons.rocket_launch_rounded,
      gradient: [Color(0xFFFF4FA3), Color(0xFF000000)],
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    await context.read<SettingsProvider>().completeOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkGrey, AppColors.deepBlack],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _complete,
                  child: const Text(AppStrings.skip),
                ),
              ).animate().fadeIn(),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPage(data: page, index: index);
                  },
                ),
              ),
              _PageIndicator(count: _pages.length, current: _currentPage),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PremiumButton(
                  label: _currentPage == _pages.length - 1
                      ? AppStrings.getStarted
                      : AppStrings.next,
                  onPressed: _next,
                  icon: _currentPage == _pages.length - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.index});

  final _OnboardingPageData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: data.gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.premiumPink.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(data.icon, size: 80, color: AppColors.white),
          )
              .animate(key: ValueKey(index))
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
          )
              .animate(key: ValueKey('title_$index'))
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
              .animate(key: ValueKey('sub_$index'))
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive ? AppColors.primaryGradient : null,
            color: isActive ? null : AppColors.mediumGrey,
          ),
        );
      }),
    );
  }
}
