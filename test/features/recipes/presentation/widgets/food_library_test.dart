import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/personal_food_list.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_all_recipes_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/merge_custom_meals_usecase.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../../helpers/widget_capture.dart';

MealEntity _food(
  String id,
  String name,
  String? unit,
  double? kcal, {
  double basis = 100,
}) => MealEntity(
  code: id,
  name: name,
  brands: '示例品牌',
  url: null,
  mealQuantity: null,
  mealUnit: unit,
  servingQuantity: null,
  servingUnit: unit,
  servingSize: null,
  nutritionBasisQuantity: basis,
  source: MealSourceEntity.custom,
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

final _foods = [
  _food('toast', '黑芝麻核桃燕麦全麦吐司（低糖款）', 'g', 268, basis: 30),
  _food('soy', '无糖豆浆', 'ml', 31),
  _food('unknown', '未填写热量的食品', null, null),
  _food('zero', '零热量食品', 'ml', 0),
];

class _Foods extends Fake implements CustomMealDataSource {
  final meals = _foods.map(MealDBO.fromMealEntity).toList();
  final deleted = <String>[];
  @override
  List<MealDBO> getAllCustomMeals() => meals;
  @override
  Future<void> deleteCustomMeal(String key) async {
    deleted.add(key);
    meals.removeWhere((m) => m.code == key);
  }
}

class _Merge extends Fake implements MergeCustomMealsUseCase {
  (String, String)? keys;
  @override
  Future<MergeCustomMealsResult> merge({
    required String loserKey,
    required String winnerKey,
  }) async {
    keys = (loserKey, winnerKey);
    return const MergeCustomMealsResult(
      rewrittenIntakeCount: 1,
      winnerDisplayName: '吐司',
    );
  }
}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

class _Recipes extends Fake implements GetAllRecipesUseCase {
  @override
  List<RecipeEntity> getAll() => [
    RecipeEntity(
      id: 'recipe',
      description: null,
      servingsCount: null,
      name: '燕麦酸奶碗',
      ingredients: const [],
      totalWeightG: 200,
      aggregatedNutrimentsPer100: _foods.first.nutriments,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class _Search extends Fake implements SearchProductsUseCase {
  bool empty = false;
  @override
  Future<List<MealEntity>> getPersonalMeals(
    String query, {
    bool favoritesOnly = false,
  }) async {
    expect(favoritesOnly, isTrue);
    return empty ? [] : [_foods[1]];
  }
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.widgetWithText(Tab, label));
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets('favorite guidance appears only in an empty unfiltered list', (
    tester,
  ) async {
    final search = _Search()..empty = true;
    locator.registerSingleton<SearchProductsUseCase>(search);
    locator.registerSingleton<GetConfigUsecase>(_Config());
    addTearDown(locator.reset);
    Future<void> pump(String query) async {
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
            home: Scaffold(
              body: PersonalFoodList(
                query: query,
                day: DateTime(2026),
                addMealType: AddMealType.lunchType,
                favoritesOnly: true,
                browseOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('');
    expect(find.textContaining('在食品详情中收藏后'), findsOneWidget);
    await pump('不存在');
    expect(find.textContaining('在食品详情中收藏后'), findsNothing);
    search.empty = false;
    await pump('');
    expect(find.text('无糖豆浆'), findsOneWidget);
    expect(find.textContaining('在食品详情中收藏后'), findsNothing);
  });
  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 1.6, false),
    (320.0, 2.0, true),
  ]) {
    testWidgets('library navigation and guarded deletion $variant', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 940);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final foods = _Foods();
      final merge = _Merge();
      final customBloc = CustomMealsBloc(foods, merge);
      final recipeBloc = RecipesBloc(_Recipes());
      final opened = <RouteSettings>[];
      locator.registerSingleton(customBloc);
      locator.registerSingleton(recipeBloc);
      locator.registerSingleton<GetConfigUsecase>(_Config());
      final search = _Search();
      locator.registerSingleton<SearchProductsUseCase>(search);
      addTearDown(() async {
        await customBloc.close();
        await recipeBloc.close();
        await locator.reset();
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: ChangeNotifierProvider(
            create: (_) => EnergyUnitProvider(),
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
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: TextScaler.linear(variant.$2)),
                child: child!,
              ),
              home: const RecipesPage(),
              onGenerateRoute: (settings) {
                opened.add(settings);
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('destination')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Renaming/reordering tabs must preserve the original recipes default.
      expect(find.widgetWithText(Tab, '配方'), findsOneWidget);
      expect(find.text('燕麦酸奶碗'), findsOneWidget);
      expect(find.textContaining('合计 536\u00a0kcal'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('燕麦酸奶碗'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      for (final entry in [
        ('创建食品', NavigationOptions.editMealRoute),
        ('创建配方', NavigationOptions.recipeBuilderRoute),
        ('导入配方', NavigationOptions.importRecipeScannerRoute),
      ]) {
        await tester.tap(find.byTooltip('新建'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(opened.last.name, entry.$2);
        if (entry.$1 == '创建食品') {
          expect(
            (opened.last.arguments as EditMealScreenArguments).editOnly,
            isTrue,
          );
        }
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }

      await _tab(tester, '我的食品');
      expect(find.text('每 30 g · 80\u00a0kcal'), findsOneWidget);
      expect(find.text('每 100 ml · 31\u00a0kcal'), findsOneWidget);
      expect(find.text('每 100 g/ml · —\u00a0kcal'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await captureWidget(
        tester,
        capture,
        'library-foods-${variant.$1}-${variant.$2}-${variant.$3}',
      );
      final library = find.ancestor(
        of: find.text('每 30 g · 80\u00a0kcal'),
        matching: find.byType(FoodLibraryList),
      );
      final scrollable = find.descendant(
        of: library,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('每 100 ml · 0\u00a0kcal'),
        150,
        scrollable: scrollable,
      );
      expect(find.text('每 100 ml · 0\u00a0kcal'), findsOneWidget);
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_foods.first.name!));
      await tester.pumpAndSettle();
      final edited = opened.last.arguments as EditMealScreenArguments;
      expect(edited.editOnly, isTrue);
      expect(edited.mealEntity.code, 'toast');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      Future<void> openDelete() async {
        await tester.tap(find.byTooltip('更多操作').first);
        await tester.pumpAndSettle();
        expect(find.text('编辑食品'), findsOneWidget);
        expect(find.text('与另一项食品合并'), findsOneWidget);
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AlertDialog, _foods.first.name!),
          findsOneWidget,
        );
        expect(find.textContaining('营养合计会保留'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await openDelete();
      await captureWidget(
        tester,
        capture,
        'library-delete-${variant.$1}-${variant.$2}-${variant.$3}',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(foods.deleted, isEmpty);
      expect(find.text(_foods.first.name!), findsOneWidget);
      await openDelete();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(foods.deleted, ['toast']);
      expect(find.text(_foods.first.name!), findsNothing);
      expect(find.text('无糖豆浆'), findsOneWidget);

      await _tab(tester, '收藏');
      expect(find.text('无糖豆浆'), findsOneWidget);
      expect(find.textContaining('浏览与管理收藏'), findsNothing);
      expect(find.textContaining('在食品详情中收藏后'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      await tester.tap(find.text('无糖豆浆'));
      await tester.pumpAndSettle();
      final detail = opened.last.arguments as MealDetailScreenArguments;
      expect(detail.browseOnly, isTrue);
      expect(detail.mealEntity.code, 'soy');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Existing merge picker and survivor confirmation still send the same IDs.
      await _tab(tester, '我的食品');
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('与另一项食品合并'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('未填写热量的食品').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          S
              .of(tester.element(find.byType(AlertDialog)))
              .customMealsMergeContinueAction,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          S
              .of(tester.element(find.byType(AlertDialog)))
              .customMealsMergeConfirmAction,
        ),
      );
      await tester.pumpAndSettle();
      expect(merge.keys, ('unknown', 'soy'));
      foods.meals.removeWhere((m) => m.code != 'soy');
      customBloc.add(LoadCustomMealsEvent());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      expect(find.text('与另一项食品合并'), findsNothing);
      expect(find.text('编辑食品'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
