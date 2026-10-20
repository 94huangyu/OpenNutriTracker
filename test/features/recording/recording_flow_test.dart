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
import 'package:opennutritracker/generated/l10n.dart';

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
  setUpAll(loadCaptureFonts);
  setUp(() {
    bloc = _DayBloc(_Intakes(), _Unused());
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
      expect(find.text('495 kcal'), findsOneWidget);
      expect(find.text('测试食品A'), findsNothing);
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
    expect(find.text('495 kcal'), findsNothing);
    expect(find.text('0 kcal'), findsNWidgets(5));
  });
}
