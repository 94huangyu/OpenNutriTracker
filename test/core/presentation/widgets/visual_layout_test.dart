import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/ingredient_quantity_dialog.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/recipe_nutrition_summary.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../helpers/widget_capture.dart';

const nutrition = MealNutrimentsEntity(
  energyKcal100: 135,
  carbohydrates100: 15,
  fat100: 4,
  proteins100: 9.5,
  sugars100: null,
  saturatedFat100: null,
  fiber100: null,
);

void main() {
  setUpAll(loadCaptureFonts);
  for (final variant in [
    (390.0, 1.0, false, false, 'zh'),
    (320.0, 1.6, false, false, 'zh'),
    (320.0, 2.0, true, true, 'zh'),
    (320.0, 2.0, true, false, 'en'),
  ]) {
    final capture = GlobalKey();
    Widget wrap(Widget child) => RepaintBoundary(
      key: capture,
      child: ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(usesKilojoules: variant.$4),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(variant.$3 ? AppPalette.dark : AppPalette.light),
          locale: Locale(variant.$5),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(variant.$2)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );

    testWidgets('recipe values remain complete at $variant', (tester) async {
      tester.view.physicalSize = Size(variant.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final huge = variant.$5 == 'en';
      final total = huge ? 20000000.0 : 200.0;
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RecipeNutritionSummary(
                nutrimentsPer100: nutrition,
                totalWeightG: total,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected = huge
          ? '27000000'
          : variant.$4
          ? '1130'
          : '270';
      final number = find.text(expected);
      expect(number, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(number);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: expected.length),
        ),
        isNotEmpty,
      );
      final card = tester.getRect(find.byType(AppCard));
      final text = tester.getRect(number);
      expect(text.left, greaterThanOrEqualTo(card.left));
      expect(text.right, lessThanOrEqualTo(card.right));
      expect(tester.takeException(), isNull);
      await captureWidget(
        tester,
        capture,
        'recipe-summary-${variant.$1}-${variant.$2}-${variant.$3}-${variant.$5}',
      );
    });

    testWidgets('ingredient sheet stays usable above keyboard at $variant', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      IngredientQuantitySelection? selected;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showIngredientQuantityDialog(
                    context,
                    meal: MealEntity(
                      code: 'oats',
                      name: '黑芝麻核桃燕麦全麦即食燕麦片（示例长名称）',
                      url: null,
                      mealQuantity: null,
                      mealUnit: 'g',
                      servingQuantity: null,
                      servingUnit: null,
                      servingSize: null,
                      source: MealSourceEntity.custom,
                      nutriments: nutrition,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '150.5');
      await tester.pumpAndSettle();
      final add = find.byType(FilledButton);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(tester.getRect(add).bottom, lessThanOrEqualTo(740 - 320 + 1));
      expect(tester.takeException(), isNull);
      await captureWidget(
        tester,
        capture,
        'ingredient-keyboard-${variant.$1}-${variant.$2}-${variant.$3}-${variant.$5}',
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(selected?.amount, 150.5);
      expect(selected?.unit, 'g');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
