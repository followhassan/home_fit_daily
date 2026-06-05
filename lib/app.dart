import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/achievements/data/repositories/achievement_repository.dart';
import 'features/achievements/presentation/providers/achievement_provider.dart';
import 'features/challenges/data/repositories/challenge_repository.dart';
import 'features/challenges/presentation/providers/challenge_provider.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/workout/data/repositories/workout_repository.dart';
import 'features/workout/presentation/providers/workout_provider.dart';

/// Root application widget with Provider setup.
class HomeFitApp extends StatelessWidget {
  const HomeFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ProfileRepository()),
        Provider(create: (_) => WorkoutRepository()),
        Provider(create: (_) => AchievementRepository()),
        Provider(create: (_) => ChallengeRepository()),
        Provider(create: (_) => SettingsRepository()),
        ChangeNotifierProvider(
          create: (ctx) => ProfileProvider(ctx.read<ProfileRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => WorkoutProvider(ctx.read<WorkoutRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              AchievementProvider(ctx.read<AchievementRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChallengeProvider(ctx.read<ChallengeRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SettingsProvider(
            ctx.read<SettingsRepository>(),
            ctx.read<AchievementRepository>(),
            ctx.read<ChallengeRepository>(),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'HomeFit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode:
                settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
