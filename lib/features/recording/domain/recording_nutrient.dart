import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

/// The existing storage units, without target or body-data assumptions.
enum RecordingNutrient {
  energy('kcal'),
  protein('g'),
  fat('g'),
  carbs('g'),
  sugars('g'),
  saturatedFat('g'),
  fiber('g'),
  monounsaturatedFat('g'),
  polyunsaturatedFat('g'),
  transFat('g'),
  cholesterol('mg'),
  sodium('mg'),
  potassium('mg'),
  magnesium('mg'),
  calcium('mg'),
  iron('mg'),
  zinc('mg'),
  phosphorus('mg'),
  vitaminA('µg'),
  vitaminC('mg'),
  vitaminD('µg'),
  vitaminB6('mg'),
  vitaminB12('µg'),
  niacin('mg');

  final String unit;
  const RecordingNutrient(this.unit);
  double? per100(MealNutrimentsEntity n) => switch (this) {
    energy => n.energyKcal100,
    protein => n.proteins100,
    fat => n.fat100,
    carbs => n.carbohydrates100,
    sugars => n.sugars100,
    saturatedFat => n.saturatedFat100,
    fiber => n.fiber100,
    monounsaturatedFat => n.monounsaturatedFat100,
    polyunsaturatedFat => n.polyunsaturatedFat100,
    transFat => n.transFat100,
    cholesterol => n.cholesterol100,
    sodium => n.sodium100,
    potassium => n.potassium100,
    magnesium => n.magnesium100,
    calcium => n.calcium100,
    iron => n.iron100,
    zinc => n.zinc100,
    phosphorus => n.phosphorus100,
    vitaminA => n.vitaminA100,
    vitaminC => n.vitaminC100,
    vitaminD => n.vitaminD100,
    vitaminB6 => n.vitaminB6100,
    vitaminB12 => n.vitaminB12100,
    niacin => n.niacin100,
  };
}
