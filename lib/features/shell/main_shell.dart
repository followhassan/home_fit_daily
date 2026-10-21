import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../app/navigation.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../../state/history_controller.dart';
import '../../state/plan_controller.dart';
import '../../state/recovery_controller.dart';
import '../guide/guide_screen.dart';
import '../home/home_screen.dart';
import '../plans/plans_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import '../workouts/workouts_hub_screen.dart';

enum ShellTab { home, workouts, plans, progress, guide }

/// Lets screens inside the shell switch tabs (e.g. a home quick action that
/// opens the exercise library).
class ShellNavigator extends InheritedWidget {
  const ShellNavigator({super.key, required this.goTo, required super.child});

  final void Function(ShellTab tab, {WorkoutsSection? section}) goTo;

  static ShellNavigator of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavigator>()!;

  @override
  bool updateShouldNotify(ShellNavigator oldWidget) => false;
}

/// The five main destinations. Each tab keeps its scroll position and
/// filters while you switch between them.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final ValueNotifier<WorkoutsSection> _workoutsSection = ValueNotifier(WorkoutsSection.workouts);
  StreamSubscription<String>? _taps;
  late final AppLifecycleListener _lifecycle;

  static const _items = [
    BottomNavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    BottomNavItem(Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Workouts'),
    BottomNavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Plans'),
    BottomNavItem(Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
    BottomNavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, 'Guide'),
  ];

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    // Tapping a reminder opens the home screen with today's workout.
    _taps = services.reminders.taps.listen((_) => _openHomeFromNotification());
    services.reminders.takeLaunchPayload().then((payload) {
      if (payload != null && mounted) _openHomeFromNotification();
    });
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    context.read<HistoryController>().refreshDay();
    context.read<PlanController>().refreshDay();
    context.read<RecoveryController>().refresh();
  }

  void _openHomeFromNotification() {
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    setState(() => _index = 0);
  }

  void _goTo(ShellTab tab, {WorkoutsSection? section}) {
    if (section != null) _workoutsSection.value = section;
    setState(() => _index = tab.index);
  }

  @override
  void dispose() {
    _taps?.cancel();
    _lifecycle.dispose();
    _workoutsSection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellNavigator(
      goTo: _goTo,
      child: PopScope(
        // Back from another tab returns to Home before leaving the app.
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _index = 0);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              const HomeScreen(),
              WorkoutsHubScreen(section: _workoutsSection),
              const PlansScreen(),
              const ProgressScreen(),
              const GuideScreen(),
            ],
          ),
          bottomNavigationBar: CustomBottomNav(
            items: _items,
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        ),
      ),
    );
  }
}

/// The settings shortcut shown in every tab's app bar.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Nav.push(context, const SettingsScreen()),
  );
}
