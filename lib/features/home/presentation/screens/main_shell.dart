import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_bottom_nav.dart';
import '../../../workout/presentation/screens/workout_plans_screen.dart';
import '../../../progress/presentation/screens/progress_screen.dart';
import '../../../challenges/presentation/screens/challenges_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    WorkoutPlansScreen(),
    ProgressScreen(),
    ChallengesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
