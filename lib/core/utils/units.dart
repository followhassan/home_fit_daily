import 'json_utils.dart';

/// Measurement unit preference. Values are always *stored* in metric units
/// (kilograms and centimetres); this only changes what is displayed.
enum UnitSystem implements JsonEnum {
  metric('metric', 'Metric (kg, cm)'),
  imperial('imperial', 'Imperial (lb, in)');

  const UnitSystem(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

/// Unit conversion helpers.
///
/// Conversion happens only for display and when the user types a new value,
/// so editing an entry without changing it never accumulates rounding drift.
abstract final class Units {
  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;

  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;
  static double cmToIn(double cm) => cm / cmPerInch;
  static double inToCm(double inches) => inches * cmPerInch;

  static String weightUnit(UnitSystem system) => system == UnitSystem.metric ? 'kg' : 'lb';

  static String lengthUnit(UnitSystem system) => system == UnitSystem.metric ? 'cm' : 'in';

  /// Converts a canonical kilogram value to the display unit.
  static double weightForDisplay(double kg, UnitSystem system) =>
      system == UnitSystem.metric ? kg : kgToLb(kg);

  /// Converts a value typed in the display unit to canonical kilograms.
  static double weightToCanonical(double value, UnitSystem system) =>
      system == UnitSystem.metric ? value : lbToKg(value);

  static double lengthForDisplay(double cm, UnitSystem system) =>
      system == UnitSystem.metric ? cm : cmToIn(cm);

  static double lengthToCanonical(double value, UnitSystem system) =>
      system == UnitSystem.metric ? value : inToCm(value);

  /// Rounds to one decimal place and drops a trailing `.0`.
  static String format(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
}
