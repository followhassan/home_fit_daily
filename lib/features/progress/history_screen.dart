import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../state/history_controller.dart';
import 'progress_screen.dart';

/// Full session history, grouped by month.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  SessionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final sessions = context
        .watch<HistoryController>()
        .sessions
        .where((s) => _status == null || s.status == _status)
        .toList();
    final items = <Widget>[];
    String? currentMonth;
    for (final s in sessions) {
      final month = DateFormat.yMMMM().format(s.localCompletionDate.toDateTime());
      if (month != currentMonth) {
        currentMonth = month;
        items.add(SectionHeader(title: month));
      }
      items.add(SessionTile(session: s));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ContentWidth(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                    ),
                  ),
                  for (final s in SessionStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.sm),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.history_rounded,
                        title: 'No sessions here',
                        message: 'Sessions you finish will be listed here.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
                      children: items,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
