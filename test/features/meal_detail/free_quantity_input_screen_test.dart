import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_capture.dart';

// Uses the real detail screen and bloc; repositories are isolated fakes.

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 100,
  carbohydrates100: 10,
  fat100: 5,
  proteins100: 5,
  sugars100: 2,
  saturatedFat100: 1,
  fiber100: 1,
);

MealEntity _solidThirtyGramServing() => MealEntity(
  code: 'chip-screen-test',
  name: '薯片样例',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: 30,
  servingUnit: 'g',
  servingSize: '30 g',
  nutriments: _nutriments,
  source: MealSourceEntity.custom,
);

void main() {
  final getIt = GetIt.instance;
  MealDetailBloc? bloc;
  final captureKey = GlobalKey();
  setUpAll(loadCaptureFonts);

  setUp(() {
    bloc = null;
    getIt.registerLazySingleton<MealDetailBloc>(
      () => bloc = MealDetailBloc(
        _FakeAddIntakeUsecase(),
        _FakeAddTrackedDayUsecase(),
        _FakeGetKcalGoalUsecase(),
        _FakeGetMacroGoalUsecase(),
        _FakeGetTrackedDayUsecase(),
        _FakeProductsRepository(),
        _FakeRemoteSearchCacheDataSource(),
        recordingOnly: true,
      ),
    );
    getIt.registerLazySingleton<GetConfigUsecase>(_FakeGetConfigUsecase.new);
    getIt.registerLazySingleton<GetIntakeUsecase>(_FakeGetIntakeUsecase.new);
    getIt.registerLazySingleton<CacheManager>(_FakeCacheManager.new);
    getIt.registerLazySingleton<HomeBloc>(_FakeHomeBloc.new);
    getIt.registerLazySingleton<DiaryBloc>(_FakeDiaryBloc.new);
    getIt.registerLazySingleton<CalendarDayBloc>(_FakeCalendarDayBloc.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpMealDetail(
    WidgetTester tester,
    MealEntity meal, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigatorKey = GlobalKey<NavigatorState>();
    Route<void> routeFor(RouteSettings settings) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const MealDetailScreen(),
      );
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ChangeNotifierProvider<EnergyUnitProvider>(
          create: (_) => EnergyUnitProvider(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(AppPalette.light),
            locale: const Locale('zh'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            navigatorKey: navigatorKey,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            initialRoute: NavigationOptions.mealDetailRoute,
            onGenerateInitialRoutes: (_) => [
              routeFor(
                RouteSettings(
                  name: NavigationOptions.mealDetailRoute,
                  arguments: MealDetailScreenArguments(
                    meal,
                    IntakeTypeEntity.breakfast,
                    DateTime(2026, 9, 14),
                    false,
                  ),
                ),
              ),
            ],
            onGenerateRoute: routeFor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('arbitrary fractional servings update the real detail bloc', (
    tester,
  ) async {
    await pumpMealDetail(tester, _solidThirtyGramServing());
    expect(find.byType(ActionChip), findsNothing);
    expect(bloc!.state.selectedUnit, 'serving');
    await tester.enterText(find.byType(TextFormField).first, '0.75');
    await tester.pumpAndSettle();
    expect(bloc!.state.totalQuantityConverted, '22.5');
    await tester.enterText(find.byType(TextFormField).first, '1.25');
    await tester.pumpAndSettle();
    expect(bloc!.state.totalQuantityConverted, '37.5');
    await captureWidget(tester, captureKey, 'intake-1.25-servings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to grams uses the typed amount directly', (
    tester,
  ) async {
    await pumpMealDetail(tester, _solidThirtyGramServing());
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '47.5');
    await tester.pumpAndSettle();
    expect(bloc!.state.selectedUnit, 'g');
    expect(bloc!.state.totalQuantityConverted, '47.5');
    await captureWidget(tester, captureKey, 'intake-47.5-grams');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'narrow large text and keyboard keep the input footer reachable',
    (tester) async {
      await pumpMealDetail(
        tester,
        _solidThirtyGramServing(),
        size: const Size(320, 700),
        scale: 1.6,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'meal-detail-add',
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(440.1));
      await captureWidget(
        tester,
        captureKey,
        'intake-narrow-large-font-keyboard',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeGetConfigUsecase implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddIntakeUsecase implements AddIntakeUsecase {
  @override
  Future<void> addIntake(IntakeEntity intakeEntity) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeAddTrackedDayUsecase implements AddTrackedDayUsecase {
  @override
  Future<bool> hasTrackedDay(DateTime day) async => true;

  @override
  Future<void> addDayCaloriesTracked(DateTime day, double kcal) async {}

  @override
  Future<void> addDayMacrosTracked(
    DateTime day, {
    double? carbsTracked,
    double? fatTracked,
    double? proteinTracked,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetKcalGoalUsecase implements GetKcalGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetMacroGoalUsecase implements GetMacroGoalUsecase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetTrackedDayUsecase implements GetTrackedDayUsecase {
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async =>
      TrackedDayEntity(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 800,
        carbsGoal: 250,
        carbsTracked: 100,
        fatGoal: 70,
        fatTracked: 30,
        proteinGoal: 120,
        proteinTracked: 50,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeProductsRepository implements ProductsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeRemoteSearchCacheDataSource implements RemoteSearchCacheDataSource {
  @override
  Future<void> touch(String barcode) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeGetIntakeUsecase implements GetIntakeUsecase {
  @override
  Future<List<IntakeEntity>> getBreakfastIntakeByDay(
    DateTime day, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeHomeBloc implements HomeBloc {
  @override
  void add(HomeEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeDiaryBloc implements DiaryBloc {
  @override
  void add(DiaryEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCalendarDayBloc implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}

class _FakeCacheManager implements CacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream<FileResponse>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}
