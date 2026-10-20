import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/merge_custom_meals_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _NoMerge extends Fake implements MergeCustomMealsUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deleting a saved template preserves all historical snapshots and totals after reopen',
    () async {
      registerHiveAdaptersOnce();
      final dir = await Directory.systemTemp.createTemp('ont-template-delete-');
      Hive.init(dir.path);
      final meals = await Hive.openBox<MealDBO>('meals');
      var intakes = await Hive.openBox<IntakeDBO>('intakes');
      var days = await Hive.openBox<TrackedDayDBO>('days');
      final meal = MealDBO(
        code: 'test',
        name: '薯片',
        brands: null,
        thumbnailImageUrl: null,
        mainImageUrl: null,
        url: null,
        mealQuantity: '60',
        mealUnit: 'g',
        servingQuantity: 15,
        servingUnit: 'g',
        servingSize: null,
        nutritionBasisQuantity: 15,
        source: MealSourceDBO.custom,
        nutriments: MealNutrimentsDBO(
          energyKcal100: 80 / 15 * 100,
          carbohydrates100: 40,
          fat100: 20,
          proteins100: 10,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );
      await meals.add(meal);
      for (var i = 1; i <= 2; i++) {
        await intakes.put(
          'i$i',
          IntakeDBO(
            id: 'i$i',
            unit: 'serving',
            amount: 7.5,
            type: IntakeTypeDBO.lunch,
            meal: meal,
            dateTime: DateTime(2026, 10, i),
          ),
        );
        await days.put(
          'd$i',
          TrackedDayDBO(
            day: DateTime(2026, 10, i),
            calorieGoal: 0,
            caloriesTracked: 40,
            carbsGoal: 0,
            carbsTracked: 3,
            fatGoal: 0,
            fatTracked: 1.5,
            proteinGoal: 0,
            proteinTracked: 0.75,
          ),
        );
      }
      final beforeIntakes = jsonEncode(
        intakes.values.map((i) => i.toJson()).toList(),
      );
      final beforeDays = jsonEncode(
        days.values.map((d) => d.toJson()).toList(),
      );
      final bloc = CustomMealsBloc(
        CustomMealDataSource(FakeHiveDBProvider(customMealBox: meals)),
        _NoMerge(),
      );
      final done = bloc.stream.firstWhere((s) => s is CustomMealsLoadedState);
      bloc.add(DeleteCustomMealEvent('test'));
      await done;
      expect(meals.values, isEmpty);
      await bloc.close();
      await intakes.close();
      await days.close();
      intakes = await Hive.openBox<IntakeDBO>('intakes');
      days = await Hive.openBox<TrackedDayDBO>('days');
      expect(
        jsonEncode(intakes.values.map((i) => i.toJson()).toList()),
        beforeIntakes,
      );
      expect(
        jsonEncode(days.values.map((d) => d.toJson()).toList()),
        beforeDays,
      );
      await Hive.close();
      await dir.delete(recursive: true);
    },
  );
}
