import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _Context extends Fake implements BuildContext {}

class _Products extends Fake implements ProductsRepository {}

class _Cache extends Fake implements RemoteSearchCacheDataSource {
  @override
  Future<void> touch(String barcode) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'first intake persists with empty body box and no activity box',
    () async {
      registerHiveAdaptersOnce();
      final directory = await Directory.systemTemp.createTemp('ont-recording-');
      Hive.init(directory.path);
      final user = await Hive.openBox<UserDBO>('user');
      final days = await Hive.openBox<TrackedDayDBO>('days');
      final intakes = await Hive.openBox<IntakeDBO>('intakes');
      final config = await Hive.openBox<ConfigDBO>('config');
      final db = FakeHiveDBProvider(
        userBox: user,
        trackedDayBox: days,
        intakeBox: intakes,
        configBox: config,
      );
      final userSource = UserDataSource(db);
      final dayRepo = TrackedDayRepository(TrackedDayDataSource(db));
      final configRepo = ConfigRepository(ConfigDataSource(db));
      final bloc = MealDetailBloc(
        AddIntakeUsecase(IntakeRepository(IntakeDataSource(db))),
        AddTrackedDayUsecase(dayRepo),
        GetKcalGoalUsecase(
          UserRepository(userSource),
          configRepo,
          UserActivityRepository(UserActivityDataSource(db)),
          recordingOnly: true,
        ),
        GetMacroGoalUsecase(configRepo),
        GetTrackedDayUsecase(dayRepo),
        _Products(),
        _Cache(),
        recordingOnly: true,
      );
      addTearDown(() async {
        await bloc.close();
        await Hive.close();
        await directory.delete(recursive: true);
      });
      expect(await userSource.hasUserData(), isFalse);
      final day = DateTime(2026, 10, 15);
      final meal = MealEntity(
        code: 'qa-food',
        name: '薯片',
        url: null,
        mealQuantity: '60',
        mealUnit: 'g',
        servingQuantity: 15,
        servingUnit: 'g',
        servingSize: '',
        nutritionBasisQuantity: 15,
        source: MealSourceEntity.custom,
        nutriments: MealNutrimentsEntity(
          energyKcal100: 80 / 15 * 100,
          carbohydrates100: 8 / 15 * 100,
          fat100: 4 / 15 * 100,
          proteins100: 3 / 15 * 100,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );
      await bloc.addIntake(
        _Context(),
        'serving',
        '7.5',
        IntakeTypeEntity.breakfast,
        meal,
        day,
      );
      expect(user.isEmpty, isTrue);
      expect(intakes.length, 1);
      final tracked = await dayRepo.getTrackedDay(day);
      expect(tracked!.calorieGoal, 0);
      expect(tracked.caloriesTracked, closeTo(40, .000001));
      expect(tracked.carbsTracked, closeTo(4, .000001));
      expect(tracked.fatTracked, closeTo(2, .000001));
      expect(tracked.proteinTracked, closeTo(1.5, .000001));
      await intakes.close();
      final reopened = await Hive.openBox<IntakeDBO>('intakes');
      expect(reopened.values.single.amount, 7.5);
      expect(reopened.values.single.meal.nutritionBasisQuantity, 15);
      expect(
        reopened.values.single.meal.nutriments.energyKcal100,
        closeTo(80 / 15 * 100, .000001),
      );
    },
  );
}
