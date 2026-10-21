import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/main_shell.dart';
import 'state/profile_controller.dart';

/// Shows onboarding until it has been completed or skipped, then the app.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<ProfileController, bool>((p) => p.onboardingCompleted);
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 350),
      child: onboarded
          ? const MainShell(key: ValueKey('main'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}
