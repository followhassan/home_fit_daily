import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../core/utils/ids.dart';
import '../core/utils/local_date.dart';
import '../core/utils/units.dart';
import '../data/models/enums.dart';
import '../data/models/personal_records.dart';
import '../data/repositories/repositories.dart';

class MeasurementValidationException implements Exception {
  const MeasurementValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Optional body measurements, stored in canonical metric units.
class MeasurementController extends ChangeNotifier {
  MeasurementController(this._repo, {this._clock = const AppClock()}) {
    _entries = _repo.all();
  }

  final MeasurementRepository _repo;
  final AppClock _clock;
  late List<MeasurementEntry> _entries;

  /// Oldest first.
  List<MeasurementEntry> entries(MeasurementType type) =>
      _entries.where((e) => e.type == type).toList();

  MeasurementEntry? latest(MeasurementType type) {
    final list = entries(type);
    return list.isEmpty ? null : list.last;
  }

  bool get hasAny => _entries.isNotEmpty;

  /// Converts a value typed in [unit] to canonical units and validates it.
  static double toCanonical(MeasurementType type, double value, UnitSystem unit) {
    final canonical = type.isWeight
        ? Units.weightToCanonical(value, unit)
        : Units.lengthToCanonical(value, unit);
    final (min, max) = type.canonicalRange;
    if (!canonical.isFinite || canonical < min || canonical > max) {
      final lo = type.isWeight
          ? Units.weightForDisplay(min, unit)
          : Units.lengthForDisplay(min, unit);
      final hi = type.isWeight
          ? Units.weightForDisplay(max, unit)
          : Units.lengthForDisplay(max, unit);
      final u = type.isWeight ? Units.weightUnit(unit) : Units.lengthUnit(unit);
      throw MeasurementValidationException(
        'Enter a value between ${Units.format(lo)} and ${Units.format(hi)} $u.',
      );
    }
    return canonical;
  }

  Future<MeasurementEntry> add({
    required MeasurementType type,
    required double value,
    required UnitSystem unit,
    LocalDate? date,
    String? note,
  }) async {
    final entry = MeasurementEntry(
      id: Ids.measurement(),
      type: type,
      canonicalValue: toCanonical(type, value, unit),
      timestampUtc: _clock.nowUtc(),
      localDate: date ?? _clock.today(),
      note: _clean(note),
    );
    await _repo.save(entry);
    _entries = _repo.all();
    notifyListeners();
    return entry;
  }

  /// Updates an entry. [value] is only converted when the user actually
  /// changed the displayed number, which avoids conversion drift.
  Future<void> update(
    MeasurementEntry entry, {
    double? value,
    required UnitSystem unit,
    LocalDate? date,
    String? note,
  }) async {
    final updated = entry.copyWith(
      canonicalValue: value == null ? entry.canonicalValue : toCanonical(entry.type, value, unit),
      localDate: date,
      note: _clean(note),
      clearNote: _clean(note) == null,
    );
    await _repo.save(updated);
    _entries = _repo.all();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _entries = _entries.where((e) => e.id != id).toList();
    notifyListeners();
  }

  String? _clean(String? note) {
    final trimmed = note?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void reload() {
    _entries = _repo.all();
    notifyListeners();
  }
}
