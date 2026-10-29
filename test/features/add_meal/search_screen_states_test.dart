import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(false, false, false, AppThemeEntity.system);
}

class _Intakes extends Fake implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getRecentIntake() async => [];
}

final rice = MealEntity(
  code: 'rice',
  name: '我的米饭',
  brands: '测试品牌',
  url: null,
  mealQuantity: '200',
  mealUnit: 'g',
  servingQuantity: 50,
  servingUnit: 'g',
  servingSize: '',
  nutritionBasisQuantity: 100,
  source: MealSourceEntity.custom,
  nutriments: const MealNutrimentsEntity(
    energyKcal100: 123,
    carbohydrates100: 26,
    fat100: 1,
    proteins100: 3,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);

final riceBall = MealEntity(
  code: 'rice-ball',
  name: '紫米饭团',
  brands: '示例品牌',
  url: null,
  mealQuantity: '120',
  mealUnit: 'g',
  servingQuantity: null,
  servingUnit: null,
  servingSize: '',
  source: MealSourceEntity.custom,
  nutriments: rice.nutriments,
);

class _Search extends Fake implements SearchProductsUseCase {
  final off = <Completer<SearchProductsResult>>[];
  final reference = <Completer<SearchProductsResult>>[];
  Future<SearchProductsResult> search(
    String query,
    bool local,
    List<Completer<SearchProductsResult>> calls,
  ) async {
    final meals = [
      rice,
      riceBall,
    ].where((meal) => meal.name!.contains(query)).toList();
    if (local) {
      return SearchProductsResult(
        meals: meals,
        remoteStatus: SearchRemoteStatus.notRequested,
      );
    }
    final c = Completer<SearchProductsResult>();
    calls.add(c);
    return c.future;
  }

  @override
  Future<SearchProductsResult> searchOFFProductsByString(
    String q, {
    bool skipRemote = false,
  }) => search(q, skipRemote, off);
  @override
  Future<SearchProductsResult> searchFDCFoodByString(
    String q, {
    bool skipRemote = false,
    bool forResolution = false,
  }) => search(q, skipRemote, reference);
  void finish() {
    for (final c in [...off, ...reference]) {
      if (!c.isCompleted) {
        c.complete(
          const SearchProductsResult(meals: [], remoteSourceEmpty: true),
        );
      }
    }
  }
}

void main() {
  final locator = GetIt.instance;
  setUpAll(loadCaptureFonts);
  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 1.0, false),
    (360.0, 1.2, false),
    (320.0, 1.6, false),
    (390.0, 1.6, false),
    (390.0, 2.0, true),
  ]) {
    testWidgets(
      'full search keeps local matches with independent sources $variant',
      (tester) async {
        tester.view.physicalSize = Size(variant.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final search = _Search();
        final config = _Config();
        locator.registerFactory<AddMealBloc>(() => AddMealBloc(config));
        locator.registerFactory<ProductsBloc>(
          () => ProductsBloc(search, config),
        );
        locator.registerFactory<FoodBloc>(() => FoodBloc(search, config));
        locator.registerFactory<RecentMealBloc>(
          () => RecentMealBloc(_Intakes(), config),
        );
        addTearDown(() async {
          search.finish();
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
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(variant.$2)),
                  child: child!,
                ),
                onGenerateRoute: (settings) {
                  if (settings.name == NavigationOptions.mealDetailRoute) {
                    final args =
                        settings.arguments as MealDetailScreenArguments;
                    expect(args.day, DateTime(2026, 10, 20));
                    expect(args.mealEntity.code, 'rice-ball');
                    expect(
                      args.intakeTypeEntity,
                      AddMealType.lunchType.getIntakeType(),
                    );
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('food-detail-opened')),
                      ),
                    );
                  }
                  if (settings.name == NavigationOptions.editMealRoute) {
                    final args = settings.arguments as EditMealScreenArguments;
                    expect(args.day, DateTime(2026, 10, 20));
                    expect(args.mealEntity.name, isNull);
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('food-editor-opened')),
                      ),
                    );
                  }
                  return MaterialPageRoute(
                    settings: RouteSettings(
                      arguments: AddMealScreenArguments(
                        AddMealType.lunchType,
                        DateTime(2026, 10, 20),
                      ),
                    ),
                    builder: (_) => const AddMealScreen(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, '全部'), findsOneWidget);
        final submit = find.byWidgetPredicate(
          (w) =>
              w is Semantics && w.properties.identifier == 'meal-search-submit',
        );
        expect(
          tester.getRect(field).height,
          closeTo(tester.getRect(submit).height, .01),
        );
        expect(
          tester.getRect(field).top,
          closeTo(tester.getRect(submit).top, .01),
        );
        Finder action(String id) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == id,
        );
        final scan = tester.getRect(action('add-meal-scan'));
        final create = tester.getRect(action('add-meal-custom-add'));
        expect(scan.width, closeTo(create.width, .01));
        expect(scan.height, closeTo(create.height, .01));
        expect(scan.left, closeTo(tester.getRect(field).left, .01));
        expect(create.right, closeTo(tester.getRect(submit).right, .01));
        if (scan.top != create.top) {
          expect(create.left, closeTo(scan.left, .01));
          expect(create.top - scan.bottom, closeTo(8, .01));
        } else {
          expect(create.left - scan.right, closeTo(12, .01));
        }
        await tester.enterText(field, '米');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.textContaining('我的米饭', findRichText: true), findsOneWidget);
        expect(search.off, isEmpty);
        expect(search.reference, isEmpty);
        expect(find.byType(NoResultsWidget), findsNothing);
        await tester.enterText(field, '米饭');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.textContaining('我的米饭', findRichText: true), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pump();
        expect(search.off, hasLength(1));
        expect(search.reference, hasLength(1));
        // Reference answered; OFF remains slow. The common local food stays once.
        search.reference.single.complete(
          SearchProductsResult(
            meals: [rice, riceBall],
            remoteStatus: SearchRemoteStatus.unconfigured,
          ),
        );
        await tester.pump();
        expect(find.textContaining('我的米饭', findRichText: true), findsOneWidget);
        expect(find.byType(NoResultsWidget), findsNothing);
        search.off.single.complete(
          SearchProductsResult(
            meals: [rice, riceBall],
            remoteStatus: SearchRemoteStatus.failed,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('我的米饭', findRichText: true), findsOneWidget);
        expect(find.textContaining('紫米饭团', findRichText: true), findsOneWidget);
        expect(find.byType(FoodListSliver), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FoodListSliver),
            matching: find.byType(Divider),
          ),
          findsOneWidget,
        );
        await captureWidget(
          tester,
          capture,
          'search-collapsed-${variant.$1}-${variant.$2}-${variant.$3}',
        );
        await tester.tap(find.textContaining('紫米饭团', findRichText: true));
        await tester.pumpAndSettle();
        expect(find.text('food-detail-opened'), findsOneWidget);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        final riceBallRow = find
            .ancestor(
              of: find.textContaining('紫米饭团', findRichText: true),
              matching: find.byType(InkWell),
            )
            .first;
        await tester.tap(
          find.descendant(
            of: riceBallRow,
            matching: find.byIcon(Icons.add_rounded),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('food-detail-opened'), findsOneWidget);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(ExpansionTile),
          180,
          scrollable: find
              .descendant(
                of: action('add-food-search-results'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.textContaining('暂不可用'), findsOneWidget);
        expect(find.textContaining('暂时无法连接'), findsOneWidget);
        expect(find.byType(NoResultsWidget), findsNothing);
        expect(tester.takeException(), isNull);
        await captureWidget(
          tester,
          capture,
          'search-full-${variant.$1}-${variant.$2}-${variant.$3}',
        );
        // Clear has no ghost rows and returns to recent, including after old calls.
        await tester.enterText(field, '');
        await tester.pumpAndSettle();
        expect(find.textContaining('我的米饭', findRichText: true), findsNothing);
        await tester.tap(find.text('创建食品').first);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('food-editor-opened'), findsOneWidget);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
