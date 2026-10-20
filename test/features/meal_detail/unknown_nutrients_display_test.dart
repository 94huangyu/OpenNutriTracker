import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

void main() {
  setUpAll(loadCaptureFonts);
  for (final imperial in [false, true]) {
    testWidgets(
      'unknown nutrients stay unknown beside known zeros; serving=$imperial',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final capture = GlobalKey();
        final meal = MealEntity(
          code: 'unknown',
          name: '未知与零',
          url: null,
          mealQuantity: '60',
          mealUnit: 'g',
          servingQuantity: 15,
          servingUnit: 'g',
          servingSize: '',
          source: MealSourceEntity.custom,
          nutriments: const MealNutrimentsEntity(
            energyKcal100: null,
            carbohydrates100: 0,
            fat100: null,
            proteins100: 2,
            sugars100: null,
            saturatedFat100: null,
            fiber100: null,
          ),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: ChangeNotifierProvider(
              create: (_) => EnergyUnitProvider(),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(AppPalette.light),
                locale: const Locale('zh'),
                supportedLocales: S.supportedLocales,
                localizationsDelegates: const [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  appBar: AppBar(title: const Text('食品营养信息')),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MealDetailNutrimentsTable(
                      product: meal,
                      usesImperialUnits: imperial,
                      servingQuantity: 15,
                      servingUnit: 'g',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('—'), findsNWidgets(5));
        expect(find.text('0.0g'), findsOneWidget);
        expect(find.text(imperial ? '0.3g' : '2.0g'), findsOneWidget);
        expect(find.textContaining('0 kcal'), findsNothing);
        expect(tester.takeException(), isNull);
        await captureWidget(
          tester,
          capture,
          'detail-unknown-versus-zero-$imperial',
        );
      },
    );
  }
}
