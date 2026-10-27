import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

MealEntity meal(
  String name,
  double? kcal, {
  String unit = 'g',
  double? basis,
  String? package = '60',
  MealSourceEntity source = MealSourceEntity.custom,
}) => MealEntity(
  code: name,
  name: name,
  brands: '测试品牌',
  url: null,
  mealQuantity: package,
  mealUnit: unit,
  servingQuantity: 15,
  servingUnit: unit,
  servingSize: '',
  nutritionBasisQuantity: basis,
  source: source,
  nutriments: MealNutrimentsEntity(
    energyKcal100: kcal,
    carbohydrates100: null,
    fat100: null,
    proteins100: null,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);
void main() {
  setUpAll(loadCaptureFonts);
  final capture = GlobalKey();
  for (final variant in [
    (390.0, 1.0, false, false),
    (320.0, 1.6, false, false),
    (390.0, 2.0, true, true),
  ]) {
    testWidgets('basis/energy/source/package remain readable $variant', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: ChangeNotifierProvider(
            create: (_) => EnergyUnitProvider(usesKilojoules: variant.$4),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(
                variant.$3 ? AppPalette.dark : AppPalette.light,
              ),
              locale: const Locale('zh'),
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
              home: Scaffold(
                appBar: AppBar(title: const Text('食品搜索')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in [
                      meal('薯片', 80 / 15 * 100, basis: 15),
                      meal(
                        '这是名称很长的中文包装食品，用来检查换行和显示',
                        0,
                        unit: 'ml',
                        package: 'NaN',
                      ),
                      meal('公共食品', null, source: MealSourceEntity.off),
                    ])
                      MealItemCard(
                        day: DateTime(2026, 10, 15),
                        mealEntity: item,
                        addMealType: AddMealType.snackType,
                        usesImperialUnits: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(variant.$4 ? '每 15 g · 335 kJ' : '每 15 g · 80 kcal'),
        findsOneWidget,
      );
      expect(
        find.text(variant.$4 ? '每 100 ml · 0 kJ' : '每 100 ml · 0 kcal'),
        findsOneWidget,
      );
      expect(
        find.text(variant.$4 ? '每 100 g · — kJ' : '每 100 g · — kcal'),
        findsOneWidget,
      );
      expect(find.text('我的食品'), findsNWidgets(2));
      expect(find.textContaining('NaN'), findsNothing);
      expect(tester.takeException(), isNull);
      await captureWidget(
        tester,
        capture,
        'search-results-${variant.$1}-${variant.$2}-${variant.$3}',
      );
    });
  }
  for (final browse in [true, false]) {
    testWidgets(
      'favorite card preserves browse versus selected meal context $browse',
      (tester) async {
        MealDetailScreenArguments? pushed;
        final day = DateTime(2026, 10, 12);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => EnergyUnitProvider(),
            child: MaterialApp(
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.supportedLocales,
              onGenerateRoute: (settings) {
                expect(settings.name, NavigationOptions.mealDetailRoute);
                pushed = settings.arguments as MealDetailScreenArguments;
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('detail')),
                );
              },
              home: Scaffold(
                body: MealItemCard(
                  day: day,
                  mealEntity: meal('收藏食品', 123),
                  addMealType: AddMealType.dinnerType,
                  usesImperialUnits: false,
                  browseOnly: browse,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'meal-item-add',
          ),
          browse ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.textContaining('收藏食品', findRichText: true));
        await tester.pumpAndSettle();
        expect(pushed!.browseOnly, browse);
        expect(pushed!.day, day);
        expect(
          pushed!.intakeTypeEntity,
          AddMealType.dinnerType.getIntakeType(),
        );
      },
    );
  }
}
