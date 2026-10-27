import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
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
  }) async => items
      .where((i) => i.type == type && DateUtils.isSameDay(i.dateTime, dateTime))
      .toList();
}

class _DayBloc extends CalendarDayBloc {
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
}
