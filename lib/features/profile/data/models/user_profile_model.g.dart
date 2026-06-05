part of 'user_profile_model.dart';

class UserProfileModelAdapter extends TypeAdapter<UserProfileModel> {
  @override
  final int typeId = 1;

  @override
  UserProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfileModel(
      name: fields[0] as String,
      age: fields[1] as int,
      gender: fields[2] as String,
      weight: fields[3] as double,
      height: fields[4] as double,
      goalWeight: fields[5] as double,
      fitnessGoal: fields[6] as String,
      totalWorkouts: fields[7] as int,
      totalCalories: fields[8] as int,
      currentStreak: fields[9] as int,
      longestStreak: fields[10] as int,
      lastWorkoutDate: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.gender)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.goalWeight)
      ..writeByte(6)
      ..write(obj.fitnessGoal)
      ..writeByte(7)
      ..write(obj.totalWorkouts)
      ..writeByte(8)
      ..write(obj.totalCalories)
      ..writeByte(9)
      ..write(obj.currentStreak)
      ..writeByte(10)
      ..write(obj.longestStreak)
      ..writeByte(11)
      ..write(obj.lastWorkoutDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
