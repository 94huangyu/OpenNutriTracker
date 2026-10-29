import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/ingredient_list_item.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/ingredient_quantity_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  testWidgets(
    'serving displays as 份 while selection and conversion remain canonical',
    (tester) async {
      final meal = MealEntity(
        code: 'fixture',
        name: '测试食材',
        url: null,
        mealQuantity: null,
        mealUnit: 'g',
        servingQuantity: 25,
        servingUnit: 'g',
        servingSize: '',
        source: MealSourceEntity.custom,
        nutriments: const MealNutrimentsEntity(
          energyKcal100: 100,
          carbohydrates100: null,
          fat100: null,
          proteins100: null,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );
      final grams = ComputeRecipeNutritionUseCase().convertAmountToGrams(
        amount: 2,
        unit: 'serving',
        servingQuantityG: meal.servingQuantity,
      )!;
      expect(grams, 50);
      final ingredient = RecipeIngredientEntity(
        snapshotMeal: meal,
        amount: 2,
        unit: 'serving',
        convertedAmountG: grams,
      );
      IngredientQuantitySelection? result;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EnergyUnitProvider(),
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: S.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    IngredientListItem(ingredient: ingredient),
                    TextButton(
                      onPressed: () async {
                        result = await showIngredientQuantityDialog(
                          context,
                          meal: meal,
                          initialAmount: 2,
                          initialUnit: ingredient.unit,
                        );
                      },
                      child: const Text('open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 份 · 50 kcal'), findsOneWidget);
      expect(find.textContaining('serving'), findsNothing);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('份'), findsOneWidget);
      expect(find.text('serving'), findsNothing);
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(result?.unit, 'serving');
      expect(result?.amount, 2);
      expect(ingredient.unit, 'serving');
      expect(ingredient.convertedAmountG, 50);
      expect(tester.takeException(), isNull);
    },
  );
}
