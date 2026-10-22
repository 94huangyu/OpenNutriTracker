import 'dart:io';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/data/dbo/profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_ingredient_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/calories_profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/physical_activity_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';
import 'personal_food_fixture.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _Paths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Every user-owned store is nonempty; the AES key and all data are synthetic.
class FullBackupFixture {
  final Directory root;
  final HiveDBProvider db;
  final PathProviderPlatform _paths;
  FullBackupService get service => FullBackupService(db, root);
  FullBackupFixture._(this.root, this.db, this._paths);
  static Future<FullBackupFixture> open() async {
    final root = await Directory.systemTemp.createTemp('ont-m4-fixture-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    final db = HiveDBProvider();
    await db.initHiveDB(Uint8List.fromList(List.generate(32, (i) => i)));
    final fixture = FullBackupFixture._(root, db, paths);
    await fixture._seed();
    return fixture;
  }

  /// Reopens only an existing synthetic fixture after a process restart.
  static Future<FullBackupFixture> reopen(Directory root) async {
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    final db = HiveDBProvider();
    await db.initHiveDB(Uint8List.fromList(List.generate(32, (i) => i)));
    await db.openProfileBoxes('p', '');
    return FullBackupFixture._(root, db, paths);
  }

  Future<void> close() async {
    await Hive.close();
    PathProviderPlatform.instance = _paths;
    await root.delete(recursive: true);
  }

  Future<void> _seed() async {
    final day = DateTime(2026, 10, 20);
    await db.profileBox.put(
      'p',
      ProfileDBO(
        id: 'p',
        name: '测试资料',
        imagePath: 'profile_images/avatar.webp',
        createdAt: day,
        boxSuffix: '',
      ),
    );
    await db.openProfileBoxes('p', '');
    final config = ConfigDBO.empty()
      ..usesKilojoules = true
      ..userCarbGoalPct = 0.45
      ..foodSourceToggles = {'bls': false}
      ..selectedLocale = 'zh'
      ..dayStartOffsetMinutes = 0;
    await db.appConfigBox.put('ConfigKey', config);
    await db.configBox.put('ConfigKey', ConfigDBO.fromJson(config.toJson()));
    final meal = MealDBO.fromMealEntity(
      food().withPersonalState(
        isFavorite: true,
        reviewSource: 'package',
        reviewNote: '包装,"逐项"\n核对',
        reviewedAt: day.toUtc(),
      ),
    );
    await db.personalFoodBox.put(food().personalKey, meal);
    await db.customMealBox.put(0, MealDBO.fromMealEntity(food(code: 'custom')));
    await db.intakeBox.put(
      0,
      IntakeDBO(
        id: 'intake',
        unit: 'g',
        amount: 25,
        type: IntakeTypeDBO.lunch,
        meal: MealDBO.fromMealEntity(food()),
        dateTime: day,
      ),
    );
    await db.trackedDayBox.put(
      '2026-10-20',
      TrackedDayDBO(
        day: day,
        calorieGoal: 1800,
        caloriesTracked: 20,
        carbsTracked: 2,
        fatTracked: 1,
        proteinTracked: 0.75,
        vitaminDGoal: 10,
      ),
    );
    await db.waterIntakeBox.put(
      'sip',
      WaterIntakeDBO(id: 'sip', dateTime: day, amountMl: 200),
    );
    await db.fastingBox.put(
      'fast',
      FastingSessionDBO(
        id: 'fast',
        startedAt: day,
        targetDurationMinutes: 720,
        cancelledAt: day.add(const Duration(hours: 2)),
      ),
    );
    await db.weightLogBox.put(
      '2026-10-20',
      WeightLogDBO(date: day, weightKg: 65, note: '历史'),
    );
    await db.userBox.put(
      'UserKey',
      UserDBO(
        birthday: DateTime(1990),
        heightCM: 165,
        weightKG: 65,
        gender: UserGenderDBO.nonBinary,
        goal: UserWeightGoalDBO.maintainWeight,
        pal: UserPALDBO.lowActive,
        weeklyWeightGoalKg: 0.2,
        caloriesProfile: CaloriesProfileDBO.averaged,
        targetWeightKg: 60,
        caloriesTaperEnabled: true,
      ),
    );
    await db.userActivityBox.put(
      0,
      UserActivityDBO(
        'historic-activity',
        20,
        100,
        day,
        PhysicalActivityDBO(
          'walk',
          'walk',
          '历史运动',
          3,
          [],
          PhysicalActivityTypeDBO.conditioningExercise,
        ),
        externalId: 'synthetic-health-id',
        sourceReportedKcal: 120,
      ),
    );
    await db.customActivityTemplateBox.put(
      '历史模板',
      CustomActivityTemplateDBO('历史模板', 123, notes: '仅备份保全'),
    );
    await db.recipeBox.put(
      0,
      RecipeDBO(
        id: 'recipe',
        name: '配方',
        description: '原料快照',
        ingredients: [
          RecipeIngredientDBO(
            snapshotMeal: MealDBO.fromMealEntity(food()),
            amount: 25,
            unit: 'g',
            convertedAmountG: 25,
          ),
        ],
        totalWeightG: 25,
        aggregatedNutrimentsPer100: MealDBO.fromMealEntity(food()).nutriments,
        createdAt: day,
        updatedAt: day,
        servingsCount: 1,
        tags: ['测试'],
        imagePath: 'recipe_images/recipe.webp',
      ),
    );
    for (final path in [
      'meal_images/test.webp',
      'recipe_images/recipe.webp',
      'profile_images/avatar.webp',
    ]) {
      final image = File('${root.path}/$path');
      await image.parent.create(recursive: true);
      await image.writeAsBytes([1, 2, 3]);
    }
    await File(
      '${root.path}/meal_images/test.webp.credit.json',
    ).writeAsString('{"name":"作者"}');
  }
}
