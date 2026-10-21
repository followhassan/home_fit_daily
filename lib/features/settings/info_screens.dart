import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';

enum InfoPage {
  privacy('Privacy'),
  disclaimer('Fitness disclaimer'),
  about('About'),
  credits('Credits & licenses');

  const InfoPage(this.title);
  final String title;
}

/// Static information pages. The text describes what the app actually does.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.page});

  final InfoPage page;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final catalog = context.read<Catalog>();
    final sections = switch (page) {
      InfoPage.privacy => _privacy,
      InfoPage.disclaimer => _disclaimer,
      InfoPage.about => [
        (
          AppConstants.appName,
          [
            'Version ${services.appVersion}. A home workout and fitness guide that works '
                'completely offline.',
            'Included: ${catalog.exercises.length} exercises, ${catalog.workouts.length} '
                'ready-made workouts, ${catalog.plans.length} four-week plans and '
                '${catalog.articles.length} guide articles (content version '
                '${catalog.contentVersion}).',
            'No account, subscription, advertising or internet connection is needed.',
          ],
        ),
      ],
      InfoPage.credits => _credits,
    };
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
            children: [
              for (final (heading, paragraphs) in sections) ...[
                SectionHeader(title: heading),
                for (final p in paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(p, style: context.text.bodyLarge?.copyWith(height: 1.5)),
                  ),
              ],
              if (page == InfoPage.credits)
                OutlinedButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: services.appVersion,
                  ),
                  child: const Text('Open-source licenses'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _privacy = [
  (
    'What is stored',
    [
      'HomeFit stores your preferences, workout history, plan progress, custom '
          'workouts, favorites, optional body measurements, notes, bookmarks and '
          'reading progress. Everything is stored only on this device.',
      'You do not need an account. The app does not ask for your email, phone '
          'number, date of birth, gender or medical history.',
    ],
  ),
  (
    'What is not collected',
    [
      'HomeFit has no analytics, advertising, tracking or crash reporting, and it '
          'does not connect to the internet. It does not use your location, camera, '
          'microphone or contacts.',
    ],
  ),
  (
    'Permissions',
    [
      'Notifications: requested only if you turn on workout reminders. Reminders '
          'are scheduled locally on the device.',
      'Files: when you export or import a backup, the system file picker lets you '
          'choose where the file goes. The app has no general access to your files.',
    ],
  ),
  (
    'Backups and device storage',
    [
      'Exported backup files are plain JSON and not encrypted. You control where '
          'they are saved and who you share them with.',
      'Uninstalling the app or clearing its storage permanently deletes your HomeFit '
          'data unless you exported a backup.',
      'Android: HomeFit opts out of Android\'s automatic cloud backup, so your data '
          'is not copied to your Google backup. Use Export to keep a copy.',
      'iOS: like other apps, HomeFit\'s data is included in your device\'s own '
          'iCloud or computer backups if you have those turned on.',
    ],
  ),
  (
    'Deleting your data',
    ['Settings → Delete all personal data erases everything the app has stored on this device.'],
  ),
];

const _disclaimer = [
  (
    'General information',
    [
      'HomeFit provides general fitness information and exercise routines for '
          'healthy adults. It is not medical advice and does not diagnose, treat or '
          'prevent any condition.',
      'Workout suggestions are based only on the preferences you chose (level, '
          'goal, equipment, duration and impact). They are not personalised medical '
          'or coaching advice.',
    ],
  ),
  (
    'Before you start',
    [
      'If you have a health condition, an injury, are pregnant or recently gave '
          'birth, take medication that affects your heart rate or balance, or are '
          'unsure whether exercise is right for you, speak to a doctor or another '
          'qualified professional first.',
    ],
  ),
  (
    'While you exercise',
    [
      'Stop immediately and rest if you feel chest pain or pressure, unusual '
          'shortness of breath, dizziness, faintness, or sharp or worsening pain. '
          'Seek urgent medical help if symptoms are severe or do not settle with rest.',
      'Use the easier variations, take extra rest and skip any exercise that does '
          'not feel right for you. You exercise at your own risk.',
    ],
  ),
  (
    'About the content',
    [
      'The exercise instructions and guide articles were written for this app and '
          'have not been reviewed by a medical or fitness professional. Each article '
          'shows its review status.',
      'Results vary between people. The app makes no promises about weight loss or '
          'specific changes to your body.',
    ],
  ),
];

const _credits = [
  (
    'Content',
    [
      'Exercise descriptions, workouts, plans, tips and guide articles are original '
          'text written for HomeFit. They have not been professionally reviewed.',
    ],
  ),
  (
    'Exercise illustrations',
    [
      'The animated stick-figure demonstrations are simplified illustrations drawn '
          'in code for this app. They show the general shape of each movement; always '
          'follow the written steps for technique details.',
    ],
  ),
  ('Sounds', ['The cue tones are simple synthesised tones generated for this app.']),
  (
    'Font',
    [
      'Inter, by The Inter Project Authors (rsms/inter), used under the SIL Open '
          'Font License 1.1. The full license is included in the open-source licenses '
          'list below.',
    ],
  ),
  (
    'Software',
    ['HomeFit is built with Flutter and open-source packages. Their licenses are listed below.'],
  ),
];
