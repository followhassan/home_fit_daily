import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/local_date.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/personal_records.dart';
import '../../state/measurement_controller.dart';
import '../../state/profile_controller.dart';

/// Optional body measurements. Values are stored in kg/cm and shown in the
/// user's preferred units.
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  MeasurementType _type = MeasurementType.weight;

  String _unit(UnitSystem system) =>
      _type.isWeight ? Units.weightUnit(system) : Units.lengthUnit(system);

  double _display(double canonical, UnitSystem system) => _type.isWeight
      ? Units.weightForDisplay(canonical, system)
      : Units.lengthForDisplay(canonical, system);

  Future<void> _edit({MeasurementEntry? entry}) async {
    final system = context.read<ProfileController>().profile.unitSystem;
    final today = context.read<AppServices>().clock.today();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntryEditor(
        type: _type,
        system: system,
        entry: entry,
        today: today,
        initialText: entry == null ? '' : Units.format(_display(entry.canonicalValue, system)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<ProfileController>().profile.unitSystem;
    final measurements = context.watch<MeasurementController>();
    final entries = measurements.entries(_type);
    final latest = entries.isEmpty ? null : entries.last;

    return Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add entry'),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 120),
          children: [
            Text(
              'Tracking is optional and stays on this device. Daily changes are often '
              'just water and food – look at the trend over several weeks.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.md),
            ChoiceChips<MeasurementType>(
              options: MeasurementType.values,
              selected: _type,
              labelOf: (t) => t.label,
              onSelected: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: Space.lg),
            if (latest == null)
              EmptyState(
                icon: Icons.straighten_rounded,
                title: 'No ${_type.label.toLowerCase()} entries',
                message: 'Add an entry whenever you like. There is no target to reach.',
                actionLabel: 'Add entry',
                onAction: () => _edit(),
              )
            else ...[
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latest', style: context.text.bodySmall),
                          Text(
                            '${Units.format(_display(latest.canonicalValue, system))} ${_unit(system)}',
                            style: context.text.headlineMedium,
                          ),
                          Text(Formatters.date(latest.localDate), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    if (entries.length > 1)
                      Builder(
                        builder: (context) {
                          final change =
                              _display(latest.canonicalValue, system) -
                              _display(entries.first.canonicalValue, system);
                          return Text(
                            '${change >= 0 ? '+' : ''}${Units.format(change)} ${_unit(system)}\nsince first entry',
                            style: context.text.bodySmall,
                            textAlign: TextAlign.end,
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (entries.length > 1) ...[
                const SizedBox(height: Space.md),
                _TrendChart(
                  values: [for (final e in entries) _display(e.canonicalValue, system)],
                  dates: [for (final e in entries) e.localDate],
                  unit: _unit(system),
                ),
              ],
              const SectionHeader(title: 'Entries'),
              for (final e in entries.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${Units.format(_display(e.canonicalValue, system))} ${_unit(system)}',
                  ),
                  subtitle: Text([Formatters.date(e.localDate), ?e.note].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Entry options',
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _edit(entry: e);
                      } else {
                        final ok = await confirmAction(
                          context,
                          title: 'Delete this entry?',
                          message: 'This measurement will be removed.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok && context.mounted) {
                          await context.read<MeasurementController>().delete(e.id);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values, required this.dates, required this.unit});

  final List<double> values;
  final List<LocalDate> dates;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final pad = ((max - min) * 0.2).clamp(1.0, double.infinity);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.lg, Space.sm),
      semanticLabel:
          'Trend chart from ${Formatters.date(dates.first)} to '
          '${Formatters.date(dates.last)}: ${Units.format(values.first)} to ${Units.format(values.last)} $unit',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: (min - pad).floorToDouble(),
              maxY: (max + pad).ceilToDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: palette.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i != 0 && i != dates.length - 1) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(Formatters.shortDate(dates[i]), style: context.text.bodySmall),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(unit, style: context.text.bodySmall),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(Units.format(value), style: context.text.bodySmall),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                  color: AppColors.premiumPink,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryEditor extends StatefulWidget {
  const _EntryEditor({
    required this.type,
    required this.system,
    required this.today,
    required this.initialText,
    this.entry,
  });

  final MeasurementType type;
  final UnitSystem system;
  final LocalDate today;
  final String initialText;
  final MeasurementEntry? entry;

  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  late final _value = TextEditingController(text: widget.initialText);
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late LocalDate _date = widget.entry?.localDate ?? widget.today;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (parsed == null) {
      setState(() => _error = 'Enter a number.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final controller = context.read<MeasurementController>();
    try {
      final entry = widget.entry;
      if (entry == null) {
        await controller.add(
          type: widget.type,
          value: parsed,
          unit: widget.system,
          date: _date,
          note: _note.text,
        );
      } else {
        // Only convert when the displayed number actually changed, so an
        // unchanged value never drifts through unit conversion.
        final changed = _value.text.trim() != widget.initialText;
        await controller.update(
          entry,
          value: changed ? parsed : null,
          unit: widget.system,
          date: _date,
          note: _note.text,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on MeasurementValidationException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.type.isWeight
        ? Units.weightUnit(widget.system)
        : Units.lengthUnit(widget.system);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.entry == null ? 'Add ${widget.type.label.toLowerCase()}' : 'Edit entry',
            style: context.text.titleLarge,
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Value', suffixText: unit, errorText: _error),
          ),
          const SizedBox(height: Space.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(Formatters.date(_date)),
            trailing: const Text('Change'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date.toDateTime(),
                firstDate: DateTime(2000),
                lastDate: widget.today.toDateTime(),
              );
              if (picked != null) setState(() => _date = LocalDate.fromDateTime(picked));
            },
          ),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: Space.sm),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
