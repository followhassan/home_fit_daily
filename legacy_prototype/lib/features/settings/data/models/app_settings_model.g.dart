part of 'app_settings_model.dart';

class AppSettingsModelAdapter extends TypeAdapter<AppSettingsModel> {
  @override
  final int typeId = 4;

  @override
  AppSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettingsModel(
      darkMode: fields[0] as bool,
      notificationsEnabled: fields[1] as bool,
      dailyWorkoutGoal: fields[2] as int,
      dailyMinutesGoal: fields[3] as int,
      dailyCaloriesGoal: fields[4] as int,
      restTimerSeconds: fields[5] as int? ?? 30,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.darkMode)
      ..writeByte(1)
      ..write(obj.notificationsEnabled)
      ..writeByte(2)
      ..write(obj.dailyWorkoutGoal)
      ..writeByte(3)
      ..write(obj.dailyMinutesGoal)
      ..writeByte(4)
      ..write(obj.dailyCaloriesGoal)
      ..writeByte(5)
      ..write(obj.restTimerSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
