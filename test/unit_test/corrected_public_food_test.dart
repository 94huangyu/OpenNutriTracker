import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

class _Preferences extends Fake implements ConfigRepository {}

class _Products extends Fake implements ProductsRepository {}

class _Recipes extends Fake implements RecipeDataSource {
  @override
  List<RecipeDBO> getAllRecipes() => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'OFF/BLS correction survives reopen, search and barcode without rewriting cache/history',
    () async {
      registerHiveAdaptersOnce();
      final dir = await Directory.systemTemp.createTemp('ont-correction-');
      Hive.init(dir.path);
      var custom = await Hive.openBox<MealDBO>('custom');
      final cached = await Hive.openBox<MealDBO>('cached');
      final timestamps = await Hive.openBox<int>('timestamps');
      final history = await Hive.openBox<IntakeDBO>('intakes');
      final source = CustomMealDataSource(
        FakeHiveDBProvider(customMealBox: custom),
      );
      final repo = IntakeRepository(
        IntakeDataSource(FakeHiveDBProvider(intakeBox: history)),
      );
      final cache = RemoteSearchCacheDataSource(cached, timestamps);
      final bloc = EditMealBloc(_Config(), source, _Preferences());
      addTearDown(() async {
        await bloc.close();
        await Hive.close();
        await dir.delete(recursive: true);
      });
      for (final type in [MealSourceEntity.off, MealSourceEntity.fdc]) {
        final public = MealEntity(
          code: type == MealSourceEntity.off ? '12345678' : 'bls,item',
          name: '原始薯片${type.name}',
          url: null,
          backendSource: type == MealSourceEntity.fdc ? 'bls' : null,
          mealQuantity: '60',
          mealUnit: 'g',
          servingQuantity: 15,
          servingUnit: 'g',
          servingSize: '',
          nutriments: MealNutrimentsEntity.empty(),
          source: type,
          detailed: true,
        );
        await cache.cache(MealDBO.fromMealEntity(public));
        await repo.addIntake(
          IntakeEntity(
            id: type.name,
            unit: 'g',
            amount: 15,
            type: IntakeTypeEntity.lunch,
            meal: public,
            dateTime: DateTime(2026, 10, 15),
          ),
        );
        final beforeCache = jsonEncode(
          cached.values.map((m) => m.toJson()).toList(),
        );
        final beforeHistory = jsonEncode(
          history.values.map((m) => m.toJson()).toList(),
        );
        final personal = bloc.createNewMealEntity(
          public,
          '我的薯片${type.name}',
          '',
          '60',
          '15',
          '15',
          'g',
          '80',
          '8',
          '4',
          '3',
          asPersonalCopy: true,
        );
        expect(
          personal.originalSource,
          type == MealSourceEntity.off ? 'off' : 'bls',
        );
        expect(personal.originalCode, public.code);
        expect(await bloc.saveCustomMeal(personal, original: public), true);
        expect(
          await bloc.saveCustomMeal(personal, original: public),
          false,
          reason: 'cannot silently overwrite a matching personal barcode',
        );
        final search = SearchProductsUseCase(
          _Products(),
          GetIntakeUsecase(repo),
          source,
          cache,
          _Recipes(),
          _Config(),
        );
        final result = await search.searchOFFProductsByString(
          '我的薯片',
          skipRemote: true,
        );
        expect(result.meals.first.source, MealSourceEntity.custom);
        final selected = result.meals.singleWhere(
          (m) => m.code == personal.code,
        );
        expect(selected.nutritionBasisQuantity, 15);
        expect(selected.nutriments.energyPerUnit! * 7.5, closeTo(40, 1e-9));
        if (type == MealSourceEntity.off) {
          final scanned = await SearchProductByBarcodeUseCase(
            _Products(),
            source,
            cache,
          ).searchProductByBarcode('12345678');
          expect(scanned.source, MealSourceEntity.custom);
          expect(scanned.name, personal.name);
        }
        expect(
          jsonEncode(cached.values.map((m) => m.toJson()).toList()),
          beforeCache,
        );
        expect(
          jsonEncode(history.values.map((m) => m.toJson()).toList()),
          beforeHistory,
        );
      }
      await custom.close();
      custom = await Hive.openBox<MealDBO>('custom');
      expect(custom.length, 2);
      for (final meal in custom.values) {
        expect(
          MealDBO.fromJson(jsonDecode(jsonEncode(meal.toJson()))).source,
          MealSourceDBO.custom,
        );
        expect(meal.originalSource, isNotNull);
        expect(meal.originalCode, meal.code);
        final encoded =
            jsonDecode(jsonEncode(meal.toJson())) as Map<String, dynamic>;
        final restored = MealDBO.fromJson(encoded);
        expect(restored.originalCode, meal.code);
        expect(restored.originalSource, meal.originalSource);
        final record = IntakeDBO(
          id: 'reference',
          unit: 'g',
          amount: 15,
          type: IntakeTypeDBO.lunch,
          meal: meal,
          dateTime: DateTime(2026, 10, 20),
        );
        final imported = CsvDataExporter.parseIntakesFromCsv(
          CsvDataExporter.intakesToCsv([record]),
        ).single.meal;
        expect(imported.originalCode, meal.code);
        expect(imported.originalSource, meal.originalSource);
        encoded.remove('originalSource');
        encoded.remove('originalCode');
        expect(MealDBO.fromJson(encoded).originalSource, isNull);
        expect(MealDBO.fromJson(encoded).originalCode, isNull);
        final originalEntity = MealEntity.fromMealDBO(meal);
        final edited = bloc.createNewMealEntity(
          originalEntity,
          '再次编辑',
          '',
          '60',
          '15',
          '15',
          'g',
          '80',
          '8',
          '4',
          '3',
          barcodeOverride: '87654321',
        );
        expect(edited.code, '87654321');
        expect(edited.originalCode, meal.code);
        expect(edited.originalSource, meal.originalSource);
        expect(meal.nutritionBasisQuantity, 15);
        expect(meal.nutriments.energyKcal100, closeTo(80 / 15 * 100, 1e-9));
      }
    },
  );
}
