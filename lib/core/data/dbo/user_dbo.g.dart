// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dbo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserDBOAdapter extends TypeAdapter<UserDBO> {
  @override
  final typeId = 5;

  @override
  UserDBO read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserDBO(
      birthday: fields[0] as DateTime,
      heightCM: (fields[1] as num).toDouble(),
      weightKG: (fields[2] as num).toDouble(),
      gender: fields[3] as UserGenderDBO,
      goal: fields[4] as UserWeightGoalDBO,
      pal: fields[5] as UserPALDBO,
      weeklyWeightGoalKg: (fields[6] as num?)?.toDouble(),
      caloriesProfile: fields[7] as CaloriesProfileDBO?,
      targetWeightKg: (fields[8] as num?)?.toDouble(),
      caloriesTaperEnabled: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserDBO obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.birthday)
      ..writeByte(1)
      ..write(obj.heightCM)
      ..writeByte(2)
      ..write(obj.weightKG)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.goal)
      ..writeByte(5)
      ..write(obj.pal)
      ..writeByte(6)
      ..write(obj.weeklyWeightGoalKg)
      ..writeByte(7)
      ..write(obj.caloriesProfile)
      ..writeByte(8)
      ..write(obj.targetWeightKg)
      ..writeByte(9)
      ..write(obj.caloriesTaperEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDBOAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDBO _$UserDBOFromJson(Map<String, dynamic> json) => UserDBO(
  birthday: DateTime.parse(json['birthday'] as String),
  heightCM: (json['heightCM'] as num).toDouble(),
  weightKG: (json['weightKG'] as num).toDouble(),
  gender: $enumDecode(_$UserGenderDBOEnumMap, json['gender']),
  goal: $enumDecode(_$UserWeightGoalDBOEnumMap, json['goal']),
  pal: $enumDecode(_$UserPALDBOEnumMap, json['pal']),
  weeklyWeightGoalKg: (json['weeklyWeightGoalKg'] as num?)?.toDouble(),
  caloriesProfile: $enumDecodeNullable(
    _$CaloriesProfileDBOEnumMap,
    json['caloriesProfile'],
  ),
  targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
  caloriesTaperEnabled: json['caloriesTaperEnabled'] as bool? ?? false,
);

Map<String, dynamic> _$UserDBOToJson(UserDBO instance) => <String, dynamic>{
  'birthday': instance.birthday.toIso8601String(),
  'heightCM': instance.heightCM,
  'weightKG': instance.weightKG,
  'gender': _$UserGenderDBOEnumMap[instance.gender]!,
  'goal': _$UserWeightGoalDBOEnumMap[instance.goal]!,
  'pal': _$UserPALDBOEnumMap[instance.pal]!,
  'weeklyWeightGoalKg': instance.weeklyWeightGoalKg,
  'caloriesProfile': _$CaloriesProfileDBOEnumMap[instance.caloriesProfile],
  'targetWeightKg': instance.targetWeightKg,
  'caloriesTaperEnabled': instance.caloriesTaperEnabled,
};

const _$UserGenderDBOEnumMap = {
  UserGenderDBO.male: 'male',
  UserGenderDBO.female: 'female',
  UserGenderDBO.nonBinary: 'nonBinary',
};

const _$UserWeightGoalDBOEnumMap = {
  UserWeightGoalDBO.loseWeight: 'loseWeight',
  UserWeightGoalDBO.maintainWeight: 'maintainWeight',
  UserWeightGoalDBO.gainWeight: 'gainWeight',
};

const _$UserPALDBOEnumMap = {
  UserPALDBO.sedentary: 'sedentary',
  UserPALDBO.lowActive: 'lowActive',
  UserPALDBO.active: 'active',
  UserPALDBO.veryActive: 'veryActive',
};

const _$CaloriesProfileDBOEnumMap = {
  CaloriesProfileDBO.averaged: 'averaged',
  CaloriesProfileDBO.estrogenTypical: 'estrogenTypical',
  CaloriesProfileDBO.testosteroneTypical: 'testosteroneTypical',
};
