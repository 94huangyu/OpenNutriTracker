import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';

class _Config extends Fake implements GetConfigUsecase {}

class _Meals extends Fake implements CustomMealDataSource {}

class _Preferences extends Fake implements ConfigRepository {}

const _nutrients = MealNutrimentsEntity(
  energyKcal100: 200,
  carbohydrates100: 20,
  fat100: 10,
  proteins100: 15,
  sugars100: 8,
  saturatedFat100: 3,
  fiber100: 4,
  monounsaturatedFat100: 2,
  polyunsaturatedFat100: 1,
  transFat100: 0,
  cholesterol100: 50,
  sodium100: 300,
  potassium100: 400,
  magnesium100: 40,
  calcium100: 100,
  iron100: 2,
  zinc100: 3,
  phosphorus100: 200,
  vitaminA100: 150,
  vitaminC100: 20,
  vitaminD100: 5,
  vitaminB6100: 0.4,
  vitaminB12100: 2,
  niacin100: 6,
);

void main() {
  late EditMealBloc bloc;
  late MealEntity old;

  setUp(() {
    bloc = EditMealBloc(_Config(), _Meals(), _Preferences());
    old = MealEntity(
      code: 'preserve-nutrients',
      name: 'Original',
      url: null,
      mealQuantity: '200',
      mealUnit: 'g',
      servingQuantity: 50,
      servingUnit: 'g',
      servingSize: '50 g',
      nutriments: _nutrients,
      source: MealSourceEntity.fdc,
      backendSource: 'bls',
      machineTranslatedName: true,
      detailed: true,
    );
  });
  tearDown(() => bloc.close());

  MealEntity edit({String base = '100', String? fiber, String? sodium}) {
    final fraction = double.parse(base) / 100;
    return bloc.createNewMealEntity(
      old,
      'Edited',
      '',
      '200',
      '50',
      base,
      'g',
      '${200 * fraction}',
      '${20 * fraction}',
      '${10 * fraction}',
      '${15 * fraction}',
      fiberText: fiber,
      sodiumText: sodium,
    );
  }

  test('unexposed nutrients survive editing with a different basis', () {
    for (final base in ['15', '50', '100']) {
      final saved = edit(base: base);
      final actual = MealNutrimentsDBO.fromProductNutrimentsEntity(
        saved.nutriments,
      ).toJson();
      final expected = MealNutrimentsDBO.fromProductNutrimentsEntity(
        _nutrients,
      ).toJson();
      for (final entry in expected.entries) {
        expect(
          actual[entry.key],
          closeTo(entry.value as num, 1e-9),
          reason: '${entry.key}, basis $base',
        );
      }
    }
  });

  test('explicitly entered nutrients are converted once', () {
    final saved = edit(base: '50', fiber: '1.5', sodium: '125');
    expect(saved.nutriments.fiber100, 3);
    expect(saved.nutriments.sodium100, 250);
    expect(saved.nutriments.calcium100, _nutrients.calcium100);
    expect(saved.nutriments.zinc100, _nutrients.zinc100);
  });

  test(
    'clearing a visible nutrient stores unknown; an omitted one survives',
    () {
      final saved = edit(fiber: '');
      expect(saved.nutriments.fiber100, isNull);
      expect(saved.nutriments.sodium100, _nutrients.sodium100);
      expect(saved.nutriments.transFat100, 0);
    },
  );

  test('editing retains the actual data-source attribution', () {
    final saved = edit();
    expect(saved.backendSource, 'bls');
    expect(saved.machineTranslatedName, isTrue);
    expect(saved.detailed, isTrue);
  });
}
