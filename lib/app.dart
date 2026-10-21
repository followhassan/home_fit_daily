import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_scope.dart';
import 'app/app_services.dart';
import 'app_root.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/hive_key_value_store.dart';
import 'features/splash/presentation/widgets/splash_content.dart';
import 'state/settings_controller.dart';

/// Root widget: bootstraps local services, then shows the app.
class HomeFitApp extends StatefulWidget {
  const HomeFitApp({super.key, this.bootstrap = bootstrapServices});

  /// Injectable for tests.
  final Future<AppServices> Function() bootstrap;

  @override
  State<HomeFitApp> createState() => _HomeFitAppState();
}

class _HomeFitAppState extends State<HomeFitApp> {
  late Future<AppServices> _services = widget.bootstrap();

  void _retry() => setState(() => _services = widget.bootstrap());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return AppScope(services: snapshot.data!, child: const _ThemedApp());
        }
        final error = snapshot.error;
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.dark,
          home: error == null
              ? const SplashContent()
              : _StartupErrorScreen(error: error, onRetry: _retry),
        );
      },
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsController, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: const AppRoot(),
    );
  }
}

class _StartupErrorScreen extends StatefulWidget {
  const _StartupErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  State<_StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<_StartupErrorScreen> {
  bool _working = false;

  Future<void> _resetBox(String box) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset damaged data?'),
        content: Text(
          'This permanently deletes the damaged "$box" data on this device. '
          'Other saved data is kept. If you have a backup file, you can '
          'import it afterwards in Settings.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await HiveKeyValueStore.deleteBox(box);
    } finally {
      if (mounted) setState(() => _working = false);
    }
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final failure = widget.error is StartupFailure
        ? widget.error as StartupFailure
        : StartupFailure(
            title: 'Something went wrong while starting',
            message: 'HomeFit could not start (${widget.error}). Please try again.',
          );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 56, color: context.palette.error),
                const SizedBox(height: Space.lg),
                Text(failure.title, style: context.text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Space.md),
                Text(failure.message, textAlign: TextAlign.center),
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: _working ? null : widget.onRetry,
                  child: const Text('Try again'),
                ),
                if (failure.boxToReset != null) ...[
                  const SizedBox(height: Space.sm),
                  TextButton(
                    onPressed: _working ? null : () => _resetBox(failure.boxToReset!),
                    child: const Text('Reset damaged data'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
