import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_all_recipes_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/merge_custom_meals_usecase.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/delete_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_activity_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_user_activity_usecase.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/splash_screen.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_portion_summary.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/custom_meals_bloc.dart';

import '../../helpers/widget_capture.dart';

// Any unexpected body/activity dependency throws instead of supplying fake data.
class _Unused extends Fake
    implements
        GetUserActivityUsecase,
        DeleteIntakeUsecase,
        DeleteUserActivityUsecase,
        AddTrackedDayUsecase,
        UpdateIntakeUsecase,
        UpdateUserActivityUsecase,
        AddConfigUsecase,
        GetTrackedDayUsecase,
        UserRepository,
        ConfigRepository {
  @override
  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async => null;
}

class _ActivityRepository extends Fake implements UserActivityRepository {}

class _Library extends Fake
    implements
        GetAllRecipesUseCase,
        CustomMealDataSource,
        MergeCustomMealsUseCase,
        SearchProductsUseCase {
  @override
  List<MealDBO> getAllCustomMeals() => [];

  @override
  Future<List<MealEntity>> getPersonalMeals(
    String query, {
    bool favoritesOnly = false,
  }) async => [];

  @override
  List<RecipeEntity> getAll() => [
    RecipeEntity(
      id: 'recipe',
      name: '测试配方',
      description: null,
      servingsCount: null,
      ingredients: const [],
      totalWeightG: 100,
      aggregatedNutrimentsPer100: a.nutriments,
      createdAt: day,
      updatedAt: day,
    ),
  ];
}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async => const ConfigEntity(
    false,
    false,
    false,
    AppThemeEntity.system,
    showActivityTracking: true,
  );
}

final day = DateTime(2026, 10, 15);
MealEntity food(String name, double serving, double kcal100) => MealEntity(
  name: name,
  code: name,
  url: null,
  servingSize: '',
  mealQuantity: '200',
  mealUnit: 'g',
  servingQuantity: serving,
  servingUnit: 'g',
  source: MealSourceEntity.custom,
  nutriments: MealNutrimentsEntity(
    energyKcal100: kcal100,
    carbohydrates100: 50,
    fat100: 20,
    proteins100: 10,
    sugars100: null,
    saturatedFat100: null,
    fiber100: null,
  ),
);
final a = food('测试食品A', 15, 80 / 15 * 100);
final b = food('测试食品B', 50, 500);
IntakeEntity intake(
  String id,
  MealEntity meal,
  double amount,
  IntakeTypeEntity type,
) => IntakeEntity(
  id: id,
  unit: 'g',
  amount: amount,
  type: type,
  meal: meal,
  dateTime: day,
);

class _Intakes extends Fake implements IntakeRepository {
  Future<void> Function(IntakeTypeEntity, DateTime)? beforeRead;
  final items = [
    intake('a1', a, 15, IntakeTypeEntity.breakfast),
    intake('a2', a, 7.5, IntakeTypeEntity.breakfast),
    intake('b1', b, 75, IntakeTypeEntity.lunch),
  ];
  @override
  Future<List<IntakeEntity>> getIntakeByDateAndType(
    IntakeTypeEntity type,
    DateTime dateTime, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    final result = items
        .where(
          (i) => i.type == type && DateUtils.isSameDay(i.dateTime, dateTime),
        )
        .toList();
    await beforeRead?.call(type, dateTime);
    return result;
  }
}

class _DayBloc extends CalendarDayBloc {
  void showLoading() => emit(CalendarDayLoading());
  Map<String, dynamic>? updated;
  IntakeEntity? deleted;
  IntakeEntity? restored;
  double? repeated;
  bool failSave = false;
  List<IntakeEntity>? copied;
  DateTime? copiedDay;
  IntakeTypeEntity? copiedType;
  List<IntakeEntity>? deletedSelected;
  @override
  Future<void> copySelectedIntakes(
    List<IntakeEntity> items,
    DateTime day,
    IntakeTypeEntity type,
  ) async {
    copied = items;
    copiedDay = day;
    copiedType = type;
  }

  @override
  Future<void> deleteSelectedIntakes(
    List<IntakeEntity> items,
    DateTime day,
  ) async {
    deletedSelected = items;
  }

  _DayBloc(_Intakes intakes, _Unused unused)
    : super(
        unused,
        GetIntakeUsecase(intakes),
        unused,
        unused,
        unused,
        unused,
        unused,
        unused,
        _Config(),
        unused,
        recordingOnly: true,
      );
  @override
  Future<void> updateIntakeItem(
    String id,
    Map<String, dynamic> fields,
    DateTime day,
  ) async {
    if (failSave) throw StateError('simulated save failure');
    updated = fields;
  }

  @override
  Future<void> deleteIntakeItem(
    BuildContext context,
    IntakeEntity item,
    DateTime day,
  ) async {
    deleted = item;
  }

  @override
  Future<void> restoreIntakeItem(IntakeEntity item, DateTime day) async {
    restored = item;
  }

  @override
  Future<void> repeatIntakeItem(
    IntakeEntity item,
    DateTime day,
    double amount,
    String unit,
  ) async {
    repeated = amount;
  }
}

Finder identified(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);

Future<void> settleDay(WidgetTester tester, CalendarDayBloc bloc) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
    if (bloc.state is! CalendarDayLoaded) {
      await bloc.stream.firstWhere((state) => state is CalendarDayLoaded);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  final getIt = GetIt.instance;
  final capture = GlobalKey();
  late _DayBloc bloc;
  late _Intakes intakes;
  AddMealScreenArguments? added;
  setUpAll(loadCaptureFonts);
  setUp(() {
    added = null;
    intakes = _Intakes();
    bloc = _DayBloc(intakes, _Unused());
    getIt.registerSingleton<CalendarDayBloc>(bloc);
    getIt.registerSingleton<GetConfigUsecase>(_Config());
    DayBoundaryCalc.clock = () => day;
  });
  tearDown(() async {
    await bloc.close();
    await getIt.reset();
    DayBoundaryCalc.clock = DateTime.now;
  });

  Future<void> pump(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool dark = false,
    Widget? home,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => EnergyUnitProvider()),
            ChangeNotifierProvider(
              create: (_) => ThemeModeProvider(
                appTheme: dark ? AppThemeEntity.dark : AppThemeEntity.light,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark ? AppPalette.dark : AppPalette.light),
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
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            onGenerateRoute: (settings) {
              if (settings.name == NavigationOptions.recipesRoute) {
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('library-route')),
                );
              }
              if (settings.name == NavigationOptions.addMealRoute) {
                added = settings.arguments as AddMealScreenArguments;
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('add-food')),
                );
              }
              return null;
            },
            home: home ?? const MainScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      if (bloc.state is! CalendarDayLoaded) {
        await bloc.stream.firstWhere((state) => state is CalendarDayLoaded);
      }
    });
    await tester.pumpAndSettle();
  }

  test(
    'recording goal never reads a missing body or exercise repository',
    () async {
      final u = _Unused();
      expect(
        await GetKcalGoalUsecase(
          u,
          u,
          _ActivityRepository(),
          recordingOnly: true,
        ).getKcalGoal(),
        0,
      );
    },
  );

  testWidgets('fresh install routes straight to diary without onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SplashScreen(userInitialized: false),
        routes: {
          NavigationOptions.mainRoute: (_) => const Text('diary'),
          NavigationOptions.onboardingRoute: (_) => const Text('body form'),
        },
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('diary'), findsOneWidget);
    expect(find.text('body form'), findsNothing);
  });

  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 1.6, false),
    (390.0, 2.0, false),
    (390.0, 1.0, true),
  ]) {
    testWidgets('collapsed intake-only diary ${variant.toString()}', (
      tester,
    ) async {
      await pump(
        tester,
        width: variant.$1,
        scale: variant.$2,
        dark: variant.$3,
      );
      expect(find.text('495 kcal', findRichText: true), findsOneWidget);
      expect(find.text('测试食品A、测试食品A'), findsOneWidget);
      expect(find.text('免责声明'), findsNothing);
      expect(find.textContaining('运动'), findsNothing);
      expect(find.textContaining('体重'), findsNothing);
      expect(find.textContaining('目标'), findsNothing);
      expect(tester.takeException(), isNull);
      await captureWidget(
        tester,
        capture,
        'recording-home-${variant.$1}-${variant.$2}-${variant.$3}',
      );
    });
  }

  testWidgets('free servings edit, independent repeat, and delete undo', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(identified('recording-meal-breakfastType'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试食品A').first);
    await tester.pumpAndSettle();
    final quantity = find.descendant(
      of: identified('recording-edit-quantity'),
      matching: find.byType(TextField),
    );
    await tester.enterText(quantity, '0');
    await tester.tap(identified('recording-save-intake'));
    await tester.pumpAndSettle();
    expect(bloc.updated, isNull);
    expect(find.text('请输入大于 0 的摄入量'), findsOneWidget);
    await tester.enterText(quantity, '15');
    await tester.pump();
    await tester.tap(identified('recording-edit-unit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('份').last);
    await tester.pumpAndSettle();
    await tester.enterText(quantity, '0.5');
    await tester.pumpAndSettle();
    expect(find.text('40 kcal'), findsWidgets);
    final numberRect = tester.getRect(quantity);
    final unitRect = tester.getRect(
      find.descendant(
        of: identified('recording-edit-unit'),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(numberRect.height, closeTo(unitRect.height, .01));
    expect(numberRect.top, closeTo(unitRect.top, .01));
    await captureWidget(tester, capture, 'recording-edit-half-serving');
    await tester.tap(identified('recording-save-intake'));
    await tester.pumpAndSettle();
    expect(bloc.updated, {'amount': 7.5, 'unit': 'serving'});
    await tester.tap(find.text('测试食品A').first);
    await tester.pumpAndSettle();
    await tester.tap(identified('recording-delete-intake'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(bloc.deleted?.id, 'a1');
    expect(find.text('已删除记录'), findsOneWidget);
    await captureWidget(tester, capture, 'recording-deleted-undo');
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(bloc.restored?.id, 'a1');
    await tester.tap(find.text('测试食品A').first);
    await tester.pumpAndSettle();
    await tester.tap(identified('recording-repeat-intake'));
    await tester.pumpAndSettle();
    expect(bloc.repeated, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date navigation shows selected date and no old totals', (
    tester,
  ) async {
    await pump(tester);
    final loaded = bloc.stream.firstWhere(
      (state) => state is CalendarDayLoaded,
    );
    await tester.tap(identified('recording-previous-day'));
    await tester.runAsync(() => loaded);
    await tester.pumpAndSettle();
    expect(find.text('2026年10月14日'), findsOneWidget);
    expect(find.text('495 kcal', findRichText: true), findsNothing);
    expect(find.text('0 kcal', findRichText: true), findsOneWidget);
    expect(find.text('尚未记录'), findsNWidgets(4));
  });
  Future<Finder> openFirstRecord(WidgetTester tester) async {
    await tester.tap(identified('recording-meal-breakfastType'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('a1')));
    await tester.pumpAndSettle();
    return find.descendant(
      of: identified('recording-edit-quantity'),
      matching: find.byType(TextField),
    );
  }

  Future<void> unit(WidgetTester tester, String label) async {
    await tester.pump();
    await tester.tap(identified('recording-edit-unit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'record summary preserves unknown energy and known zero independently',
    (tester) async {
      final unknown = MealEntity(
        name: '未知热量样例',
        code: 'nullable-record',
        url: null,
        mealQuantity: '200',
        mealUnit: 'g',
        servingQuantity: 50,
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
      intakes.items
        ..clear()
        ..add(intake('a1', unknown, 50, IntakeTypeEntity.breakfast));
      await pump(tester);
      final input = await openFirstRecord(tester);
      var summary = tester.widget<FoodPortionSummary>(
        find.byType(FoodPortionSummary),
      );
      expect(summary.kcal, isNull);
      expect(summary.carbs, 0);
      expect(summary.fat, isNull);
      expect(summary.protein, 1);
      expect(
        find.descendant(
          of: find.byType(FoodPortionSummary),
          matching: find.text('— kcal', findRichText: true),
        ),
        findsOneWidget,
      );
      await tester.enterText(input, '20');
      await tester.pumpAndSettle();
      summary = tester.widget<FoodPortionSummary>(
        find.byType(FoodPortionSummary),
      );
      expect(summary.protein, .4);
      expect(summary.kcal, isNull);
      await captureWidget(tester, capture, 'recording-edit-unknown-energy');
      await tester.tap(identified('recording-save-intake'));
      await tester.pumpAndSettle();
      expect(bloc.updated, {'amount': 20.0, 'unit': 'g'});
      expect(unknown.nutriments.energyKcal100, isNull);
    },
  );

  testWidgets(
    'record editor long name and large font keep save above keyboard; cancel does not save',
    (tester) async {
      intakes.items[0] = intake(
        'a1',
        food('很长的食品名称' * 10, 30, 500),
        100,
        IntakeTypeEntity.breakfast,
      );
      await pump(tester, width: 320, scale: 1.6);
      final quantity = await openFirstRecord(tester);
      await tester.ensureVisible(quantity);
      await tester.enterText(quantity, '45');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(identified('recording-save-intake'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(identified('recording-save-intake')).bottom,
        lessThanOrEqualTo(640),
      );
      await captureWidget(tester, capture, 'recording-edit-narrow-keyboard');
      await tester.ensureVisible(identified('recording-cancel-intake'));
      await tester.pumpAndSettle();
      await tester.tap(identified('recording-cancel-intake'));
      await tester.pumpAndSettle();
      expect(bloc.updated, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final serving in [30.0, 50.0]) {
    testWidgets(
      'unit-only round trips preserve exact 100g with serving $serving',
      (tester) async {
        intakes.items[0] = intake(
          'a1',
          food('换算测试', serving, 123),
          100,
          IntakeTypeEntity.breakfast,
        );
        await pump(tester);
        final quantity = await openFirstRecord(tester);
        for (var i = 0; i < 5; i++) {
          await unit(tester, '份');
          expect(
            double.parse(tester.widget<TextField>(quantity).controller!.text),
            100 / serving,
          );
          await unit(tester, 'g');
          expect(tester.widget<TextField>(quantity).controller!.text, '100');
        }
        await unit(tester, '份');
        await tester.tap(identified('recording-save-intake'));
        await tester.pumpAndSettle();
        expect(bloc.updated, {'amount': 100.0, 'unit': 'serving'});
        expect(intakes.items.first.amount, 100);
      },
    );
  }

  testWidgets(
    'invalid input disables conversion; failed save and cancel keep original',
    (tester) async {
      await pump(tester);
      final quantity = await openFirstRecord(tester);
      for (final invalid in ['', '0', 'NaN', '-1']) {
        await tester.enterText(quantity, invalid);
        await tester.pump();
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        );
        expect(dropdown.onChanged, isNull);
        await tester.tap(identified('recording-save-intake'));
        await tester.pumpAndSettle();
        expect(bloc.updated, isNull);
      }
      await tester.enterText(quantity, '30');
      await unit(tester, '份');
      bloc.failSave = true;
      await tester.tap(identified('recording-save-intake'));
      await tester.pumpAndSettle();
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(bloc.updated, isNull);
      expect(intakes.items.first.amount, 15);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(bloc.updated, isNull);
    },
  );

  for (final serving in [0.0, double.infinity, double.nan]) {
    testWidgets('no convertible serving for $serving', (tester) async {
      intakes.items[0] = intake(
        'a1',
        food('无份量', serving, 123),
        100,
        IntakeTypeEntity.breakfast,
      );
      await pump(tester);
      await openFirstRecord(tester);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNotNull);
      await tester.tap(identified('recording-edit-unit'));
      await tester.pumpAndSettle();
      expect(find.text('份'), findsNothing);
      await tester.tap(find.text('g').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 1.6, false),
    (390.0, 2.0, true),
  ]) {
    testWidgets(
      'meal detail selects records, cancels delete and copies to chosen date and meal $variant',
      (tester) async {
        await pump(
          tester,
          width: variant.$1,
          scale: variant.$2,
          dark: variant.$3,
        );
        await tester.tap(identified('recording-meal-breakfastType'));
        await tester.pumpAndSettle();
        expect(find.text('测试食品A'), findsNWidgets(2));
        await captureWidget(
          tester,
          capture,
          'recording-meal-detail-${variant.$1}-${variant.$2}-${variant.$3}',
        );
        await tester.tap(identified('recording-meal-edit'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('a1')));
        await tester.pump();
        await tester.tap(identified('recording-delete-selected'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '取消').last);
        await tester.pumpAndSettle();
        expect(bloc.deletedSelected, isNull);
        await tester.tap(identified('recording-copy-selected'));
        await tester.pumpAndSettle();
        await tester.tap(identified('recording-copy-date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('20').last);
        await tester.tap(find.text('确定').last);
        await tester.pumpAndSettle();
        await tester.tap(identified('recording-copy-meal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('晚餐').last);
        await tester.pumpAndSettle();
        await captureWidget(
          tester,
          capture,
          'recording-copy-destination-${variant.$1}-${variant.$2}-${variant.$3}',
        );
        await tester.tap(find.widgetWithText(FilledButton, '复制').last);
        await tester.pumpAndSettle();
        expect(bloc.copied!.map((i) => i.id), ['a1']);
        expect(bloc.copiedDay, DateTime(2026, 10, 20));
        expect(bloc.copiedType, IntakeTypeEntity.dinner);
        expect(intakes.items.length, 3);
        await tester.tap(identified('recording-meal-edit'));
        await tester.pump();
        await tester.tap(identified('recording-select-all'));
        await tester.pump();
        await tester.tap(identified('recording-delete-selected'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '删除').last);
        await tester.pumpAndSettle();
        expect(bloc.deletedSelected!.map((i) => i.id), ['a1', 'a2']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'each plus opens the chosen historical date and meal independently',
    (tester) async {
      await pump(tester);
      for (final type in AddMealType.values) {
        await tester.tap(identified('recording-add-${type.name}'));
        await tester.pumpAndSettle();
        expect(added!.day, day);
        expect(added!.mealType, type);
        expect(find.text('add-food'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      final loaded = bloc.stream.firstWhere(
        (state) => state is CalendarDayLoaded,
      );
      await tester.tap(identified('recording-previous-day'));
      await tester.runAsync(() => loaded);
      await tester.pumpAndSettle();
      await tester.tap(identified('recording-add-dinnerType'));
      await tester.pumpAndSettle();
      expect(added!.day, DateTime(2026, 10, 14));
      expect(added!.mealType, AddMealType.dinnerType);
    },
  );

  testWidgets('long names remain complete in narrow large-text meal detail', (
    tester,
  ) async {
    final name = '一条很长的食品名称用于确认首页省略之后餐次详情仍然能够完整显示每一项记录';
    intakes.items[0] = intake(
      'a1',
      food(name, 30, 123),
      100,
      IntakeTypeEntity.breakfast,
    );
    await pump(tester, width: 320, scale: 1.6);
    final preview = tester.widget<Text>(find.text('$name、测试食品A'));
    expect(preview.maxLines, 1);
    expect(preview.overflow, TextOverflow.ellipsis);
    await tester.tap(identified('recording-meal-breakfastType'));
    await tester.pumpAndSettle();
    final full = tester.widget<Text>(find.text(name));
    expect(full.maxLines, isNull);
    await captureWidget(tester, capture, 'recording-detail-narrow-long-name');
    expect(tester.takeException(), isNull);
  });
  for (final mealDetail in [false, true]) {
    for (final safeBottom in [0.0, 24.0]) {
      testWidgets(
        'read-only ${mealDetail ? "meal detail" : "home"} keeps its viewport after input route closes with delayed IME metrics ($safeBottom)',
        (tester) async {
          tester.view.viewPadding = FakeViewPadding(bottom: safeBottom);
          tester.view.padding = FakeViewPadding(bottom: safeBottom);
          await pump(tester, width: 320, scale: 1.6);
          if (mealDetail) {
            await tester.tap(identified('recording-meal-breakfastType'));
            await tester.pumpAndSettle();
          }
          final viewport = find.byType(ListView).first;
          final before = tester.getRect(viewport);
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: TextField(autofocus: true)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '米饭');
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          tester.view.padding = FakeViewPadding.zero;
          await tester.pumpAndSettle();
          navigator.pop();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          expect(tester.testTextInput.isVisible, isFalse);
          final whileMetricsDelayed = tester.getRect(viewport);
          await captureWidget(
            tester,
            capture,
            'keyboard-return-${mealDetail ? "meal" : "home"}-$safeBottom',
          );
          tester.view.viewInsets = FakeViewPadding.zero;
          tester.view.padding = FakeViewPadding(bottom: safeBottom);
          await tester.pumpAndSettle();
          expect(tester.getRect(viewport), before);
          expect(whileMetricsDelayed, before);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final save in [false, true]) {
    testWidgets(
      'record sheet ${save ? "save" : "cancel"} keeps keyboard avoidance without shrinking returned pages',
      (tester) async {
        await pump(tester, width: 320, scale: 1.6);
        final homeViewport = tester.getRect(find.byType(ListView).first);
        await tester.tap(identified('recording-meal-breakfastType'));
        await tester.pumpAndSettle();
        final mealViewport = tester.getRect(find.byType(ListView).first);
        await tester.tap(find.text('测试食品A').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: identified('recording-edit-quantity'),
            matching: find.byType(TextField),
          ),
          '12.5',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        final action = identified(
          save ? 'recording-save-intake' : 'recording-cancel-intake',
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(bloc.updated?['amount'], save ? 12.5 : null);
        expect(tester.getRect(find.byType(ListView).first), mealViewport);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(ListView).first), homeViewport);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(ListView).first), homeViewport);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'input tabs keep keyboard avoidance and returning home leaves no gap',
    (tester) async {
      final data = _Library();
      final recipes = RecipesBloc(data);
      final custom = CustomMealsBloc(data, data);
      getIt.registerSingleton(recipes);
      getIt.registerSingleton(custom);
      getIt.registerSingleton<SearchProductsUseCase>(data);
      addTearDown(() async {
        await recipes.close();
        await custom.close();
      });
      await pump(tester);
      final homeViewport = tester.getRect(find.byType(ListView).first);
      await tester.tap(find.byIcon(Icons.kitchen_outlined).last);
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      final libraryScaffold = find
          .ancestor(of: field, matching: find.byType(Scaffold))
          .first;
      final scaffold = tester.widget<Scaffold>(libraryScaffold);
      final body = find.byWidget(scaffold.body!);
      final bodyBeforeKeyboard = tester.getRect(body);
      await tester.tap(field);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(body).height, lessThan(bodyBeforeKeyboard.height));
      intakes.items[0] = intake('a1', a, 30, IntakeTypeEntity.breakfast);
      await tester.tap(find.byIcon(Icons.today_outlined));
      await settleDay(tester, bloc);
      final hiddenFields = tester.widgetList<EditableText>(
        find.byType(EditableText, skipOffstage: false),
      );
      expect(hiddenFields.any((field) => field.focusNode.hasFocus), isFalse);
      expect(tester.getRect(find.byType(ListView).first), homeViewport);
      expect(find.text('575 kcal', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  String shownDay(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: identified('recording-date'),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets(
    'returning from food library reloads the selected day automatically',
    (tester) async {
      await pump(tester);
      await tester.tap(identified('recording-food-library'));
      await tester.pumpAndSettle();
      expect(find.text('library-route'), findsOneWidget);
      intakes.items[0] = intake('a1', a, 30, IntakeTypeEntity.breakfast);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settleDay(tester, bloc);
      expect(find.text('575 kcal', findRichText: true), findsOneWidget);
      expect(shownDay(tester), '2026年10月15日');
    },
  );

  Future<void> dayDrag(
    WidgetTester tester,
    Offset delta, {
    double? startX,
  }) async {
    final area = tester.getRect(identified('recording-day-content'));
    await tester.dragFrom(
      Offset(startX ?? area.center.dx, area.top + 60),
      delta,
    );
    await settleDay(tester, bloc);
  }

  testWidgets('swipe changes one day and each plus retains that date', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(RefreshIndicator), findsNothing);
    await dayDrag(tester, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(shownDay(tester), '2026年10月14日');
    await tester.tap(identified('recording-add-dinnerType'));
    await tester.pumpAndSettle();
    expect(added!.day, DateTime(2026, 10, 14));
    expect(added!.mealType, AddMealType.dinnerType);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await dayDrag(tester, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(shownDay(tester), '2026年10月15日');
    expect(find.text('495 kcal', findRichText: true), findsOneWidget);
    await dayDrag(tester, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(shownDay(tester), '2026年10月16日');
  });

  testWidgets(
    'short, vertical, diagonal and system edge drags do not change day',
    (tester) async {
      tester.view.systemGestureInsets = const FakeViewPadding(
        left: 24,
        right: 24,
      );
      await pump(tester, width: 320, scale: 1.6);
      final before = shownDay(tester);
      for (final delta in [
        const Offset(45, 0),
        const Offset(0, 140),
        const Offset(40, 140),
        const Offset(100, 100),
      ]) {
        await dayDrag(tester, delta);
        await tester.pumpAndSettle();
        expect(shownDay(tester), before);
      }
      await dayDrag(tester, const Offset(160, 0), startX: 8);
      await tester.pumpAndSettle();
      expect(shownDay(tester), before);
      await dayDrag(tester, const Offset(-160, 0), startX: 312);
      await tester.pumpAndSettle();
      expect(shownDay(tester), before);
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading surface still accepts a date swipe', (tester) async {
    await pump(tester);
    await tester.runAsync(() async {
      bloc.showLoading();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await dayDrag(tester, const Offset(160, 0));
    expect(shownDay(tester), '2026年10月14日');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dates in [
    (DateTime(2026, 1, 1), '2025年12月31日'),
    (DateTime(2028, 3, 1), '2028年2月29日'),
  ]) {
    testWidgets('swipe follows calendar boundaries from ${dates.$1}', (
      tester,
    ) async {
      DayBoundaryCalc.clock = () => dates.$1;
      await pump(tester);
      await dayDrag(tester, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(shownDay(tester), dates.$2);
    });
  }

  for (final first in [true, false]) {
    testWidgets(
      'date limit keeps arrows, swipe and picker consistent ($first)',
      (tester) async {
        DayBoundaryCalc.clock = () => first ? DateTime(2000) : DateTime(2100);
        await pump(tester);
        final before = shownDay(tester);
        final arrow = find.descendant(
          of: identified(
            first ? 'recording-previous-day' : 'recording-next-day',
          ),
          matching: find.byType(IconButton),
        );
        expect(tester.widget<IconButton>(arrow).onPressed, isNull);
        await dayDrag(tester, Offset(first ? 160 : -160, 0));
        await tester.pumpAndSettle();
        expect(shownDay(tester), before);
        await tester.tap(identified('recording-date'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final refresh in [false, true]) {
    test(
      'latest request wins even after returning to the same date (refresh=$refresh)',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        var firstRead = true;
        intakes.beforeRead = (type, _) async {
          if (type == IntakeTypeEntity.breakfast && firstRead) {
            firstRead = false;
            started.complete();
            await release.future;
          }
        };
        bloc.add(LoadCalendarDayEvent(day));
        try {
          await started.future;
          intakes.items[0] = intake('fresh', a, 30, IntakeTypeEntity.breakfast);
          final loaded = bloc.stream.firstWhere(
            (state) => state is CalendarDayLoaded,
          );
          if (refresh) {
            bloc.add(const RefreshCalendarDayEvent());
          } else {
            bloc.add(LoadCalendarDayEvent(DateUtils.addDaysToDate(day, 1)));
            bloc.add(LoadCalendarDayEvent(day));
          }
          await loaded;
        } finally {
          release.complete();
        }
        // The released queries only schedule microtasks; let them all drain.
        await Future<void>.delayed(Duration.zero);
        expect(
          (bloc.state as CalendarDayLoaded).breakfastIntakeList.first.amount,
          30,
        );
      },
    );
  }
}
