// Synthetic load for the dedicated validation installation only.
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/profile_bootstrap.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/settings/domain/backup/backup_dataset.dart';
import '../../test/helpers/personal_food_fixture.dart';
import 'm5_isolated_restore.dart' show requireValidationPackage, check;

Future<Map<String, Object>> seedPerformanceFixture(String package) async {
  requireValidationPackage(package);
  final secure = SecureAppStorageProvider();
  final db = HiveDBProvider();
  await db.initHiveDB(await secure.getHiveEncryptionKey());
  await bootstrapActiveProfile(db, secure);
  // Refuse existing records instead of clearing/reseeding any installation.
  for (final dataset in backupDatasets) {
    if (dataset.name == HiveDBProvider.profileBoxName) continue;
    check((await dataset.open(db, '')).isEmpty, 'Performance store not empty');
  }
  final config = ConfigDBO.empty()..selectedLocale = 'zh';
  await db.appConfigBox.put('ConfigKey', config);
  await db.configBox.put('ConfigKey', ConfigDBO.fromJson(config.toJson()));
  final meals = List.generate(
    20,
    (i) => MealDBO.fromMealEntity(
      food(
        code: 'M5-perf-$i',
        source: MealSourceEntity.custom,
        name: 'M5 合成食品 $i',
      ),
    ),
  );
  await db.customMealBox.putAll({
    for (var i = 0; i < meals.length; i++) i: meals[i],
  });
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final rows = <int, IntakeDBO>{};
  final totals = <DateTime, List<double>>{};
  for (var i = 0; i < 1000; i++) {
    final day = today.subtract(Duration(days: i < 200 ? 0 : 1 + i % 89));
    final row = IntakeDBO(
      id: 'M5-perf-$i',
      unit: 'g',
      amount: 25,
      type: IntakeTypeDBO.values[i % 4],
      meal: meals[i % meals.length],
      dateTime: day.add(Duration(hours: 8 + i % 12)),
    );
    rows[i] = row;
    final e = IntakeEntity.fromIntakeDBO(row);
    final sums = totals.putIfAbsent(day, () => [0, 0, 0, 0]);
    sums[0] += e.totalKcal;
    sums[1] += e.totalCarbsGram;
    sums[2] += e.totalFatsGram;
    sums[3] += e.totalProteinsGram;
  }
  await db.intakeBox.putAll(rows);
  await db.trackedDayBox.putAll({
    for (final e in totals.entries)
      '${e.key.year}-${e.key.month.toString().padLeft(2, '0')}-${e.key.day.toString().padLeft(2, '0')}':
          TrackedDayDBO(
            day: e.key,
            calorieGoal: 0,
            caloriesTracked: e.value[0],
            carbsTracked: e.value[1],
            fatTracked: e.value[2],
            proteinTracked: e.value[3],
          ),
  });
  check(db.userBox.isEmpty, 'Synthetic load must not invent body information');
  final result = <String, Object>{
    'intakes': db.intakeBox.length,
    'todayIntakes': 200,
    'days': totals.length,
    'customFoods': db.customMealBox.length,
    'bodyProfiles': 0,
    'todayKcal': totals[today]![0],
  };
  await Hive.close();
  return result;
}
