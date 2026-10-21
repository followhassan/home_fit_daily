// GENERATED MANUALLY - Hive TypeAdapter
part of 'workout_history_model.dart';

class WorkoutHistoryModelAdapter extends TypeAdapter<WorkoutHistoryModel> {
  @override
  final int typeId = 0;

  @override
  WorkoutHistoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutHistoryModel(
      id: fields[0] as String,
      planId: fields[1] as String,
      planName: fields[2] as String,
      completedAt: fields[3] as DateTime,
      durationSeconds: fields[4] as int,
      caloriesBurned: fields[5] as int,
      exerciseCount: fields[6] as int,
      difficulty: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutHistoryModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.planId)
      ..writeByte(2)
      ..write(obj.planName)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.caloriesBurned)
      ..writeByte(6)
      ..write(obj.exerciseCount)
      ..writeByte(7)
      ..write(obj.difficulty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutHistoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
