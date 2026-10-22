import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// One explicit allowlist for portable backups and encrypted rollback journals.
/// No public cache, secure-storage key, or service credential enters this list.
class BackupDataset<T> {
  final String name;
  final T Function(Map<String, dynamic>) decode;
  final Map<String, dynamic> Function(T) encode;
  final String Function(T, dynamic) identity;
  final bool global;
  const BackupDataset(
    this.name,
    this.decode,
    this.encode,
    this.identity, {
    this.global = false,
  });

  Future<Box<T>> open(HiveDBProvider db, String suffix) =>
      db.openScopedBox<T>(name, suffix);

  Future<void> close(HiveDBProvider db, String suffix) =>
      db.closeScopedBox<T>(name, suffix);

  Future<List<Map<String, dynamic>>> read(
    HiveDBProvider db,
    String suffix,
  ) async {
    final box = await open(db, suffix);
    // JSON detaches nested DBOs and prevents later mutations of the snapshot.
    return (jsonDecode(
              jsonEncode([
                for (final row in box.toMap().entries)
                  {'key': row.key, 'value': encode(row.value)},
              ]),
            )
            as List)
        .cast<Map<String, dynamic>>();
  }

  void validate(List<dynamic> rows) {
    final keys = <dynamic>{};
    final ids = <String>{};
    for (final row in rows) {
      final key = row['key'];
      if ((key is! String && key is! int) ||
          (key is int && (key < 0 || key > 0xFFFFFFFF)) ||
          (key is String && utf8.encode(key).length > 255) ||
          !keys.add(key)) {
        throw const FormatException('Invalid or duplicate storage key');
      }
      final value = decode(Map<String, dynamic>.from(row['value'] as Map));
      final id = identity(value, key);
      final requiredKey = switch (name) {
        HiveDBProvider.configBoxName ||
        HiveDBProvider.appConfigBoxName => 'ConfigKey',
        HiveDBProvider.userBoxName => 'UserKey',
        HiveDBProvider.personalFoodBoxName ||
        HiveDBProvider.weightLogBoxName ||
        HiveDBProvider.trackedDayBoxName ||
        HiveDBProvider.profileBoxName => id,
        _ => null,
      };
      if (requiredKey != null && key != requiredKey) {
        throw const FormatException('Record key does not match its identity');
      }
      if (id.isEmpty || !ids.add(id)) {
        throw const FormatException('Invalid or duplicate record identity');
      }
    }
  }

  Future<void> replace(
    HiveDBProvider db,
    String suffix,
    List<dynamic> rows,
  ) async {
    final box = await open(db, suffix);
    final values = <dynamic, T>{
      for (final row in rows)
        row['key']: decode(Map<String, dynamic>.from(row['value'] as Map)),
    };
    await box.clear();
    await box.putAll(values);
    await box.flush();
  }

  String rowIdentity(Map<String, dynamic> row) => identity(
    decode(Map<String, dynamic>.from(row['value'] as Map)),
    row['key'],
  );
}

String _key(dynamic value, dynamic key) => key.toString();
String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _meal(MealDBO meal, dynamic key) =>
    jsonEncode([meal.source.name, meal.backendSource, meal.code ?? meal.name]);

final backupDatasets = <BackupDataset>[
  BackupDataset<ProfileDBO>(
    HiveDBProvider.profileBoxName,
    ProfileDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
    global: true,
  ),
  BackupDataset<ConfigDBO>(
    HiveDBProvider.appConfigBoxName,
    ConfigDBO.fromJson,
    (v) => v.toJson(),
    _key,
    global: true,
  ),
  BackupDataset<MealDBO>(
    HiveDBProvider.customMealBoxName,
    MealDBO.fromJson,
    (v) => v.toJson(),
    _meal,
    global: true,
  ),
  BackupDataset<MealDBO>(
    HiveDBProvider.personalFoodBoxName,
    MealDBO.fromJson,
    (v) => v.toJson(),
    (v, k) {
      final meal = MealEntity.fromMealDBO(v);
      if (!meal.canSavePersonalState ||
          ((meal.reviewSource != null ||
                  meal.reviewNote != null ||
                  meal.reviewedAt != null) &&
              !meal.isPersonallyReviewed)) {
        throw const FormatException('Invalid personal food evidence');
      }
      return meal.personalKey;
    },
    global: true,
  ),
  BackupDataset<RecipeDBO>(
    HiveDBProvider.recipeBoxName,
    RecipeDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
    global: true,
  ),
  BackupDataset<CustomActivityTemplateDBO>(
    HiveDBProvider.customActivityTemplateBoxName,
    CustomActivityTemplateDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.name,
    global: true,
  ),
  BackupDataset<ConfigDBO>(
    HiveDBProvider.configBoxName,
    ConfigDBO.fromJson,
    (v) => v.toJson(),
    _key,
  ),
  BackupDataset<IntakeDBO>(
    HiveDBProvider.intakeBoxName,
    IntakeDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
  ),
  BackupDataset<UserActivityDBO>(
    HiveDBProvider.userActivityBoxName,
    UserActivityDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
  ),
  BackupDataset<UserDBO>(
    HiveDBProvider.userBoxName,
    UserDBO.fromJson,
    (v) => v.toJson(),
    _key,
  ),
  BackupDataset<TrackedDayDBO>(
    HiveDBProvider.trackedDayBoxName,
    TrackedDayDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => _date(v.day),
  ),
  BackupDataset<WeightLogDBO>(
    HiveDBProvider.weightLogBoxName,
    WeightLogDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => _date(v.date),
  ),
  BackupDataset<WaterIntakeDBO>(
    HiveDBProvider.waterIntakeBoxName,
    WaterIntakeDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
  ),
  BackupDataset<FastingSessionDBO>(
    HiveDBProvider.fastingBoxName,
    FastingSessionDBO.fromJson,
    (v) => v.toJson(),
    (v, k) => v.id,
  ),
];

BackupDataset datasetNamed(String name) =>
    backupDatasets.firstWhere((d) => d.name == name);
