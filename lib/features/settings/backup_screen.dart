import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/local_date.dart';
import '../../core/widgets/common.dart';
import '../../domain/backup/backup_codec.dart';
import '../../domain/backup/restore_service.dart';
import '../../state/data_controller.dart';

/// Export and import of personal data as a JSON file the user controls.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _working = false;

  Future<void> _export() async {
    final data = context.read<DataController>();
    setState(() => _working = true);
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save HomeFit backup',
        fileName: data.exportFileName(),
        bytes: data.exportBackup(),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (!mounted) return;
      showMessage(context, uri == null ? 'Export cancelled' : 'Backup saved');
    } catch (e) {
      if (mounted) showMessage(context, 'The backup could not be saved.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _import() async {
    final data = context.read<DataController>();
    setState(() => _working = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a HomeFit backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null || !mounted) return;
      final length = await file.length();
      if (length != null && length > BackupCodec.maxBytes) {
        if (mounted) _showErrors(['This file is too large to be a HomeFit backup (over 10 MB).']);
        return;
      }
      final validation = data.validateBackup(await file.readAsBytes());
      if (!mounted) return;
      if (!validation.isValid) {
        _showErrors(validation.errors);
        return;
      }
      final confirmed = await _confirmImport(validation);
      if (!confirmed || !mounted) return;
      await data.importBackup(validation.document!);
      if (mounted) showMessage(context, 'Backup imported');
    } on RestoreFailedException {
      if (mounted) {
        _showErrors([
          'The import could not be completed. Your previous data has been kept unchanged.',
        ]);
      }
    } catch (e) {
      if (mounted) _showErrors(['The file could not be read.']);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showErrors(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup not imported'),
        content: SingleChildScrollView(
          child: Text(
            '${errors.take(8).join('\n')}${errors.length > 8 ? '\n…and ${errors.length - 8} more.' : ''}'
            '\n\nNothing was changed.',
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<bool> _confirmImport(BackupValidation validation) async {
    final s = validation.summary!;
    final exported = s.exportedAtUtc.toLocal();
    final lines = [
      'Exported ${Formatters.date(LocalDate.fromDateTime(exported))}',
      '${s.sessions} sessions (${s.completedSessions} completed)',
      '${s.customWorkouts} custom workouts',
      '${s.favorites} favorites · ${s.bookmarks} bookmarks',
      '${s.measurements} measurements · ${s.enrollments} plan enrollments',
      if (!s.hasProfile) 'No profile (you will see onboarding again)',
    ];
    return confirmAction(
      context,
      title: 'Replace your data with this backup?',
      message:
          '${lines.join('\n')}\n\n'
          '${validation.warnings.isEmpty ? '' : '${validation.warnings.join('\n')}\n\n'}'
          'All current HomeFit data on this device will be replaced, and any '
          'unfinished workout is discarded. A copy of your current data is kept '
          'so you can undo the import.',
      confirmLabel: 'Import',
      destructive: true,
    );
  }

  Future<void> _undo() async {
    final ok = await confirmAction(
      context,
      title: 'Undo the last import?',
      message: 'Your data will go back to how it was just before the last import.',
      confirmLabel: 'Undo import',
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await context.read<DataController>().undoLastImport();
      if (mounted) showMessage(context, 'Previous data restored');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not restore the previous data.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final undoDate = context.watch<DataController>().undoImportDate;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              Text(
                'Your data lives only on this device. A backup file lets you keep a '
                'copy or move your data to another device.',
                style: context.text.bodyLarge,
              ),
              const SizedBox(height: Space.md),
              AppCard(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_open_rounded, color: context.palette.warning),
                    const SizedBox(width: Space.md),
                    const Expanded(
                      child: Text(
                        'Backup files are not encrypted. They contain your personal '
                        'information (profile, workout history, measurements and notes). '
                        'Store and share them carefully.',
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Export'),
              Text(
                'Includes your profile, settings, favorites, custom workouts, history, '
                'plan progress, measurements, bookmarks and reading progress. Built-in '
                'workouts and media are not included because they come with the app.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: _working ? null : _export,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Export backup'),
              ),
              const SectionHeader(title: 'Import'),
              Text(
                'The file is checked before anything changes. If it is damaged or from '
                'a newer app version, nothing is imported.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: _working ? null : _import,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Import backup'),
              ),
              if (undoDate != null) ...[
                const SectionHeader(title: 'Undo import'),
                Text(
                  'Data from before your last import (${Formatters.date(LocalDate.fromDateTime(undoDate.toLocal()))}) '
                  'is still available on this device.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Space.md),
                OutlinedButton.icon(
                  onPressed: _working ? null : _undo,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Restore data from before the import'),
                ),
              ],
              if (_working)
                const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
