import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/core/utils/units.dart';

void main() {
  group('LocalDate', () {
    test('parses and formats ISO dates', () {
      expect(LocalDate.parse('2026-03-09').toIso(), '2026-03-09');
      expect(LocalDate.tryParse('2026-02-30'), isNull);
      expect(LocalDate.tryParse('not a date'), isNull);
      expect(LocalDate.tryParse(null), isNull);
    });

    test('weeks start on Monday', () {
      // 2026-10-21 is a Wednesday.
      final wednesday = LocalDate.parse('2026-10-21');
      expect(wednesday.weekday, 3);
      expect(wednesday.startOfWeek, LocalDate.parse('2026-10-19'));
      final sunday = LocalDate.parse('2026-10-25');
      expect(sunday.startOfWeek, LocalDate.parse('2026-10-19'));
      final monday = LocalDate.parse('2026-10-26');
      expect(monday.startOfWeek, monday);
    });

    test('day arithmetic crosses month, year and leap-day boundaries', () {
      expect(LocalDate.parse('2026-01-31').addDays(1), LocalDate.parse('2026-02-01'));
      expect(LocalDate.parse('2026-12-31').addDays(1), LocalDate.parse('2027-01-01'));
      expect(LocalDate.parse('2028-02-28').addDays(1), LocalDate.parse('2028-02-29'));
      expect(LocalDate.parse('2027-01-02').daysSince(LocalDate.parse('2026-12-30')), 3);
    });

    test('arithmetic is unaffected by daylight-saving transitions', () {
      // Dates around common DST changes still differ by exactly one day.
      for (final iso in ['2026-03-08', '2026-03-29', '2026-10-25', '2026-11-01']) {
        final d = LocalDate.parse(iso);
        expect(d.addDays(1).daysSince(d), 1);
      }
    });

    test('month helpers', () {
      final d = LocalDate.parse('2026-02-14');
      expect(d.startOfMonth, LocalDate.parse('2026-02-01'));
      expect(d.daysInMonth, 28);
      expect(d.addMonthsToStart(-2), LocalDate.parse('2025-12-01'));
      expect(d.addMonthsToStart(11), LocalDate.parse('2027-01-01'));
    });
  });

  group('Units', () {
    test('converts weight and length', () {
      expect(Units.kgToLb(100), closeTo(220.462, 0.001));
      expect(Units.inToCm(10), 25.4);
    });

    test('display/canonical round trips do not drift', () {
      var kg = 72.5;
      for (var i = 0; i < 100; i++) {
        final shown = Units.weightForDisplay(kg, UnitSystem.imperial);
        kg = Units.weightToCanonical(shown, UnitSystem.imperial);
      }
      expect(kg, closeTo(72.5, 1e-9));
    });

    test('formats to one decimal place', () {
      expect(Units.format(72.0), '72');
      expect(Units.format(72.04), '72');
      expect(Units.format(72.06), '72.1');
    });
  });
}
