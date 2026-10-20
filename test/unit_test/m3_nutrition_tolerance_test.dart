import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  test('both fiber conventions, rounding and missing core nutrients', () {
    // Available carbs: 10*4 + 15*2 = 70; total carbs: 10*4 - 8*2 = 24.
    expect(
      labelEnergyNeedsReview(
        kcal: 70,
        carbs: 10,
        fat: 0,
        protein: 0,
        fiber: 15,
      ),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: 24, carbs: 10, fat: 0, protein: 0, fiber: 8),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: 5, carbs: 0, fat: 0, protein: 0),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: 40, carbs: null, fat: 0, protein: 0),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: double.nan, carbs: 2, fat: 0, protein: 0),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(
        kcal: 40,
        carbs: double.infinity,
        fat: 0,
        protein: 0,
      ),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: 40, carbs: -2, fat: 0, protein: 0),
      isFalse,
    );
    expect(
      labelEnergyNeedsReview(kcal: 0, carbs: 10, fat: 0, protein: 0),
      isTrue,
    );
    expect(
      labelEnergyNeedsReview(kcal: 500, carbs: 8, fat: 4, protein: 3),
      isTrue,
    );
  });

  test('composition respects original basis, subsets, rounding, and mL', () {
    expect(
      labelCompositionNeedsReview(
        carbs: 8,
        fat: 4,
        protein: 3,
        sugars: 8.5,
        saturatedFat: 4.1,
        basis: 15,
        isLiquid: false,
      ),
      isFalse,
    );
    expect(
      labelCompositionNeedsReview(
        carbs: 8,
        fat: 4,
        protein: 3,
        sugars: 10,
        basis: 15,
        isLiquid: false,
      ),
      isTrue,
    );
    expect(
      labelCompositionNeedsReview(
        carbs: 8,
        fat: 4,
        protein: 3,
        saturatedFat: 6,
        basis: 15,
        isLiquid: false,
      ),
      isTrue,
    );
    expect(
      labelCompositionNeedsReview(
        carbs: 14,
        fat: 4,
        protein: 3,
        basis: 15,
        isLiquid: false,
      ),
      isTrue,
    );
    expect(
      labelCompositionNeedsReview(
        carbs: 105,
        fat: 2,
        protein: 3,
        basis: 100,
        isLiquid: true,
      ),
      isFalse,
    );
    final n = MealNutrimentsEntity(
      energyKcal100: 450,
      carbohydrates100: 105,
      fat100: 2,
      proteins100: 3,
      sugars100: 0,
      saturatedFat100: 0,
      fiber100: null,
    );
    expect(validateNutriments(n, checkMassLimit: false).isConsistent, isTrue);
    expect(validateNutriments(n).isConsistent, isFalse);
  });
}
