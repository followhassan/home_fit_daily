import 'package:uuid/uuid.dart';

/// Generates stable unique identifiers for personal records.
abstract final class Ids {
  static const _uuid = Uuid();

  static String session() => 'session_${_uuid.v4()}';
  static String customWorkout() => 'custom_${_uuid.v4()}';
  static String customStep() => 'step_${_uuid.v4()}';
  static String enrollment() => 'enrollment_${_uuid.v4()}';
  static String measurement() => 'measurement_${_uuid.v4()}';
  static String profile() => 'profile_${_uuid.v4()}';
}
