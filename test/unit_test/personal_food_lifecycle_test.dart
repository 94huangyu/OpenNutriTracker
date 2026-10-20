import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';
import '../helpers/personal_food_fixture.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

class _Intakes extends Fake implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getRecentIntake() async => [];
}

class _Products extends Fake implements ProductsRepository {}

void main() {
  late Directory root;
  late Box<MealDBO> personal, templates, cached;
  late Box<IntakeDBO> diary;
  late Box<RecipeDBO> recipes;
  late Box<int> times;
  late PersonalFoodDataSource store;
  late CustomMealDataSource custom;
  setUp(() async {
    registerHiveAdaptersOnce();
    root = await Directory.systemTemp.createTemp('ont-personal-lifecycle-');
    Hive.init(root.path);
    personal = await Hive.openBox<MealDBO>('personal');
    templates = await Hive.openBox<MealDBO>('templates');
    cached = await Hive.openBox<MealDBO>('cached');
    diary = await Hive.openBox<IntakeDBO>('diary');
    recipes = await Hive.openBox<RecipeDBO>('recipes');
    times = await Hive.openBox<int>('times');
    store = PersonalFoodDataSource(personal);
    custom = CustomMealDataSource(
      FakeHiveDBProvider(customMealBox: templates),
      personalFoods: store,
    );
  });
  tearDown(() async {
    store.dispose();
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'edit/delete template and personal evidence cannot rewrite stored diary snapshot',
    () async {
      final meal = food(source: MealSourceEntity.custom);
      await custom.saveCustomMeal(MealDBO.fromMealEntity(meal));
      await store.setFavorite(meal, true);
      final reviewed = await store.review(meal, 'package', '包装资料');
      await diary.add(
        IntakeDBO(
          id: 'one',
          unit: 'g',
          amount: 15,
          type: IntakeTypeDBO.lunch,
          meal: MealDBO.fromMealEntity(reviewed),
          dateTime: DateTime(2026, 10, 20),
        ),
      );
      final before = jsonEncode(diary.values.map((i) => i.toJson()).toList());
      // A no-op edit retains evidence. A numeric edit retains only favorite.
      await custom.updateCustomMeal(
        MealDBO.fromMealEntity(meal),
        originalCode: meal.code,
      );
      expect(store.apply(meal).isPersonallyReviewed, isTrue);
      final changed = food(
        source: MealSourceEntity.custom,
        energy: 90,
        code: 'new',
      );
      await custom.updateCustomMeal(
        MealDBO.fromMealEntity(changed),
        originalCode: meal.code,
      );
      expect(store.apply(changed).isFavorite, isTrue);
      expect(store.apply(changed).isPersonallyReviewed, isFalse);
      expect(store.apply(meal).isFavorite, isFalse);
      await custom.deleteCustomMeal('new');
      expect(store.getAll(), isEmpty);
      await diary.close();
      diary = await Hive.openBox<IntakeDBO>('diary');
      expect(jsonEncode(diary.values.map((i) => i.toJson()).toList()), before);
      expect(diary.values.single.meal.reviewNote, '包装资料');
      expect(diary.values.single.meal.nutriments.energyKcal100, 80);
    },
  );

  test(
    'blank favorite/my filters and Chinese single-character search are local; barcode survives empty cache',
    () async {
      final meal = food();
      await store.setFavorite(meal, true);
      await custom.saveCustomMeal(
        MealDBO.fromMealEntity(
          food(code: 'custom', source: MealSourceEntity.custom),
        ),
      );
      final cache = RemoteSearchCacheDataSource(cached, times);
      final search = SearchProductsUseCase(
        _Products(),
        _Intakes(),
        custom,
        cache,
        RecipeDataSource(FakeHiveDBProvider(recipeBox: recipes)),
        _Config(),
        personalFoods: store,
      );
      final favorites = await search.getPersonalMeals('', favoritesOnly: true);
      expect(favorites.single.source, MealSourceEntity.off);
      expect(favorites.single.isPersonallyReviewed, isFalse);
      expect(
        (await search.getPersonalMeals('')).single.source,
        MealSourceEntity.custom,
      );
      expect(
        (await search.getPersonalMeals('牛', favoritesOnly: true)).single.code,
        meal.code,
      );
      expect(await search.getPersonalMeals('米', favoritesOnly: true), isEmpty);
      final local = await search.searchOFFProductsByString(
        '牛',
        skipRemote: true,
      );
      expect(local.meals.length, 2);
      final scanned = await SearchProductByBarcodeUseCase(
        _Products(),
        custom,
        cache,
        personalFoods: store,
      ).searchProductByBarcode(meal.code!);
      expect(scanned.isFavorite, isTrue);
      expect(cached.values, isEmpty);
      await store.setFavorite(meal, false);
      expect(await search.getPersonalMeals('', favoritesOnly: true), isEmpty);
    },
  );
}
