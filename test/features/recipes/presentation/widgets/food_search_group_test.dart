import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/food_search_tab_view.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../../helpers/widget_capture.dart';

final foods = [
  for (var i = 0; i < 2; i++)
    MealEntity(
      code: 'food-$i',
      name: i == 0 ? '示例米饭' : '示例米饭团',
      brands: '示例品牌',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      source: MealSourceEntity.custom,
      nutriments: MealNutrimentsEntity.empty(),
    ),
];

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

class _Search extends Fake implements SearchProductsUseCase {
  @override
  Future<SearchProductsResult> searchOFFProductsByString(
    String q, {
    bool skipRemote = false,
  }) async => SearchProductsResult(
    meals: foods,
    remoteStatus: SearchRemoteStatus.results,
  );
  @override
  Future<SearchProductsResult> searchFDCFoodByString(
    String q, {
    bool skipRemote = false,
    bool forResolution = false,
  }) async => SearchProductsResult(
    meals: foods,
    remoteStatus: SearchRemoteStatus.results,
  );
}

class _Intakes extends Fake implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getRecentIntake() async => [
    for (final food in foods)
      IntakeEntity(
        id: food.code!,
        unit: 'g',
        amount: 100,
        type: IntakeTypeEntity.lunch,
        meal: food,
        dateTime: DateTime(2026),
      ),
  ];
}

void main() {
  setUpAll(loadCaptureFonts);
  for (final variant in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'ingredient product food and recent lists share a group at $variant',
      (tester) async {
        final config = _Config();
        final search = _Search();
        locator.registerFactory<ProductsBloc>(
          () => ProductsBloc(search, config),
        );
        locator.registerFactory<FoodBloc>(() => FoodBloc(search, config));
        locator.registerFactory<RecentMealBloc>(
          () => RecentMealBloc(_Intakes(), config),
        );
        addTearDown(locator.reset);
        tester.view.physicalSize = Size(variant.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        MealEntity? selected;
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(variant.$2)),
                child: child!,
              ),
              home: Scaffold(
                body: FoodSearchTabView(
                  onMealSelected: (meal) => selected = meal,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '米饭');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byType(Tab).at(i));
          await tester.pumpAndSettle();
          expect(find.byType(FoodListSliver), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(FoodListSliver),
              matching: find.byType(Divider),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('示例米饭 示例品牌', findRichText: true));
          expect(selected?.code, 'food-0');
          expect(tester.takeException(), isNull);
          await captureWidget(
            tester,
            capture,
            'ingredient-search-${variant.$1}-${variant.$2}-$i',
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
