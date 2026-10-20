import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

MealEntity food({
  String code = 'same',
  MealSourceEntity source = MealSourceEntity.off,
  String? backend,
  double energy = 80,
  String name = '牛奶',
}) => MealEntity(
  code: code,
  name: name,
  url: null,
  mealQuantity: '60',
  mealUnit: 'g',
  servingQuantity: 15,
  servingUnit: 'g',
  servingSize: '15g',
  nutritionBasisQuantity: 15,
  source: source,
  backendSource: backend,
  detailed: true,
  nutriments: MealNutrimentsEntity(
    energyKcal100: energy,
    carbohydrates100: 8,
    fat100: 4,
    proteins100: 3,
    sugars100: 1,
    saturatedFat100: 2,
    fiber100: 1,
    sodium100: 12,
    vitaminA100: 300,
  ),
);
