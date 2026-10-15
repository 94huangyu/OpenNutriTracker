import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/meal_detail/util/meal_quantity_converter.dart';

import '../helpers/hive_test_setup.dart';

class _Config extends Fake implements GetConfigUsecase {}

class _Meals extends Fake implements CustomMealDataSource {}

class _Preferences extends Fake implements ConfigRepository {}

// Frozen using the unmodified v2.4.0 MealDBO adapter before adding field 18.
// Synthetic food only: package 60 g, serving 15 g, 533.333... kcal / 100 g.
const _legacyHive =
    '0gAAAAEFY2hpcHMhEgAEDAAAAGxlZ2FjeS1jaGlwcwEEDwAAAOaXp+mjn+WTgeagt+S+iwIAAwAEAAUABgQCAAAANjAHBAEAAABnCAIAAAAAAAAuQAkEAQAAAGcKLgELIxgAAquqqqqqqoBAAQKrqqqqqqpKQAICq6qqqqqqOkADAquqqqqqqhpABAAFAAYABwAIAAkACgALAAwADQAOAA8AEAIAAAAAAAAAQBEAEgIAAAAAAMByQBMAFAAVABYAFwAMAA0ADgAPABAAEQBo4si2';

void main() {
  late EditMealBloc bloc;
  setUp(() => bloc = EditMealBloc(_Config(), _Meals(), _Preferences()));
  tearDown(() => bloc.close());

  MealEntity create(
    String package,
    String serving,
    String basis,
    String energy, {
    String unit = 'g',
  }) => bloc.createNewMealEntity(
    MealEntity.empty(),
    '薯片样例',
    '',
    package,
    serving,
    basis,
    unit,
    energy,
    '8',
    '4',
    '1',
  );

  test('energy review allows rounding, has no opinion on missing values', () {
    expect(labelEnergyNeedsReview(kcal: 80, carbs: 8, fat: 4, protein: 3), isFalse);
    expect(labelEnergyNeedsReview(kcal: 84, carbs: 8, fat: 4, protein: 3), isFalse);
    expect(labelEnergyNeedsReview(kcal: 500, carbs: 8, fat: 4, protein: 3), isTrue);
    expect(labelEnergyNeedsReview(kcal: 0, carbs: 10, fat: 0, protein: 0), isTrue);
    expect(labelEnergyNeedsReview(kcal: 80, carbs: null, fat: 4, protein: 3), isFalse);
  });

  test('clearing a barcode retains an internal custom-food identity', () {
    final old = create('60','15','15','80');
    final changed = bloc.createNewMealEntity(old,'薯片样例','','60','15','15','g',
        '80','8','4','3',barcodeOverride:'');
    expect(changed.code, isNotEmpty);
    expect(changed.code, isNot(old.code));
    expect(changed.code, contains('-'));
  });

  test('60 / 15 / 15: grams and arbitrary serving counts agree', () {
    final meal = create('60', '15', '15', '80');
    expect(meal.mealQuantity, '60');
    expect(meal.servingQuantity, 15);
    expect(meal.effectiveNutritionBasis, 15);
    expect(meal.nutriments.energyKcal100, closeTo(533.3333333333, 1e-8));
    expect(kcalForQuantity(0.5, 'serving', meal), closeTo(40, 1e-8));
    expect(kcalForQuantity(7.5, 'g', meal), closeTo(40, 1e-8));
    expect(kcalForQuantity(1.25, 'serving', meal), closeTo(100, 1e-8));
    expect(kcalForQuantity(60, 'g', meal), closeTo(320, 1e-8));
  });

  test('200 / 50 / 100: packaging is never the nutrient denominator', () {
    final meal = create('200', '50', '100', '500');
    expect(meal.effectiveNutritionBasis, 100);
    expect(kcalForQuantity(1.5, 'serving', meal), 375);
    expect(kcalForQuantity(75, 'g', meal), 375);
    expect(kcalForQuantity(200, 'g', meal), 1000);
  });

  test('mL serving conversion keeps the volume basis', () {
    final meal = create('250', '125', '100', '60', unit: 'ml');
    expect(meal.mealUnit, 'ml');
    expect(meal.servingUnit, 'ml');
    expect(kcalForQuantity(0.5, 'serving', meal), 37.5);
    expect(kcalForQuantity(25, 'ml', meal), 15);
  });

  test(
    'JSON and CSV preserve basis and canonical nutrients; old files read',
    () {
      final meal = MealDBO.fromMealEntity(create('60', '15', '15', '80'));
      final json =
          jsonDecode(jsonEncode(meal.toJson())) as Map<String, dynamic>;
      final restored = MealDBO.fromJson(json);
      expect(restored.nutritionBasisQuantity, 15);
      expect(restored.nutriments.energyKcal100, meal.nutriments.energyKcal100);
      json.remove('nutritionBasisQuantity');
      expect(
        MealEntity.fromMealDBO(MealDBO.fromJson(json)).effectiveNutritionBasis,
        100,
      );

      final intake = IntakeDBO(
        id: 'test',
        unit: 'g',
        amount: 15,
        type: IntakeTypeDBO.snack,
        meal: meal,
        dateTime: DateTime(2026, 10, 15),
      );
      final csv = CsvDataExporter.intakesToCsv([intake]);
      final imported = CsvDataExporter.parseIntakesFromCsv(csv).single;
      expect(imported.meal.nutritionBasisQuantity, 15);
      expect(IntakeEntity.fromIntakeDBO(imported).totalKcal, closeTo(80, 1e-8));
      final oldCsv = csv
          .trimRight()
          .split('\n')
          .map((line) => line.substring(0, line.lastIndexOf(',')))
          .join('\n');
      final legacy = CsvDataExporter.parseIntakesFromCsv(oldCsv).single;
      expect(legacy.meal.nutritionBasisQuantity, isNull);
      expect(IntakeEntity.fromIntakeDBO(legacy).totalKcal, closeTo(80, 1e-8));
    },
  );

  test(
    'real legacy Hive file reads without changing stored nutrients',
    () async {
      final root = await Directory.systemTemp.createTemp('ont-basis-legacy-');
      addTearDown(() async {
        await Hive.close();
        await root.delete(recursive: true);
      });
      Hive.init(root.path);
      registerHiveAdaptersOnce();
      await File(
        '${root.path}/legacy_custom_meals.hive',
      ).writeAsBytes(base64Decode(_legacyHive));
      final box = await Hive.openBox<MealDBO>('legacy_custom_meals');
      final meal = box.get('chips')!;
      expect(meal.nutritionBasisQuantity, isNull);
      expect(meal.mealQuantity, '60');
      expect(meal.servingQuantity, 15);
      expect(meal.nutriments.zinc100, 2);
      expect(meal.nutriments.vitaminA100, 300);
      expect(MealEntity.fromMealDBO(meal).effectiveNutritionBasis, 100);
      expect(
        kcalForQuantity(1, 'serving', MealEntity.fromMealDBO(meal)),
        closeTo(80, 1e-8),
      );
    },
  );

  test(
    'Hive save/reopen keeps label basis and historical intake snapshot',
    () async {
      final root = await Directory.systemTemp.createTemp('ont-basis-new-');
      addTearDown(() async {
        await Hive.close();
        await root.delete(recursive: true);
      });
      Hive.init(root.path);
      registerHiveAdaptersOnce();
      var foods = await Hive.openBox<MealDBO>('foods');
      var diary = await Hive.openBox<IntakeDBO>('diary');
      final original = MealDBO.fromMealEntity(create('60', '15', '15', '80'));
      await foods.put('chips', original);
      await diary.put(
        'intake',
        IntakeDBO(
          id: 'intake',
          unit: 'g',
          amount: 15,
          type: IntakeTypeDBO.snack,
          meal: original,
          dateTime: DateTime(2026, 10, 15),
        ),
      );
      await foods.put(
        'chips',
        MealDBO.fromMealEntity(create('60', '15', '15', '90')),
      );
      await foods.close();
      await diary.close();
      foods = await Hive.openBox<MealDBO>('foods');
      diary = await Hive.openBox<IntakeDBO>('diary');
      final read = MealEntity.fromMealDBO(foods.get('chips')!);
      expect(read.effectiveNutritionBasis, 15);
      expect(kcalForQuantity(1, 'serving', read), closeTo(90, 1e-8));
      expect(
        IntakeEntity.fromIntakeDBO(diary.get('intake')!).totalKcal,
        closeTo(80, 1e-8),
      );
    },
  );
}
