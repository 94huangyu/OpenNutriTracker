import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

import '../../../helpers/widget_capture.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);
}

class _Preferences extends Fake implements ConfigRepository {
  String mode = 'simple';
  @override
  Future<String?> getCustomMealFormMode() async => mode;
  @override
  Future<void> setCustomMealFormMode(String value) async {
    mode = value;
  }
}

class _Meals extends Fake implements CustomMealDataSource {
  final saved = <MealDBO>[];
  @override
  Future<void> saveCustomMeal(MealDBO meal) async {
    saved.add(meal);
  }

  @override
  Future<bool> updateCustomMeal(
    MealDBO meal, {
    String? originalCode,
    String? originalName,
  }) async {
    saved.add(meal);
    return true;
  }
}

Finder identified(String id) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == id,
);
Finder input(String id) => find.descendant(
  of: identified('edit-meal-$id'),
  matching: find.byType(TextFormField),
);

void main() {
  final getIt = GetIt.instance;
  late _Meals meals;
  late _Preferences preferences;
  final captureKey = GlobalKey();
  setUpAll(loadCaptureFonts);
  setUp(() {
    meals = _Meals();
    preferences = _Preferences();
    getIt.registerFactory<EditMealBloc>(
      () => EditMealBloc(_Config(), meals, preferences),
    );
  });
  tearDown(() => getIt.reset());

  Future<void> pumpEditor(
    WidgetTester tester, {
    MealEntity? meal,
    double width = 390,
    double scale = 1,
    bool dark = false,
    bool kj = false,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final palette = dark ? AppPalette.dark : AppPalette.light;
    final actualArgs = EditMealScreenArguments(
      DateTime(2026, 10, 15),
      meal ?? MealEntity.empty(),
      IntakeTypeEntity.snack,
      false,
      editOnly: true,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ChangeNotifierProvider<EnergyUnitProvider>(
          create: (_) => EnergyUnitProvider(usesKilojoules: kj),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(palette),
            locale: const Locale('zh'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('saved')),
            ),
            onGenerateInitialRoutes: (_) => [
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('saved')),
              ),
              MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: NavigationOptions.editMealRoute,
                  arguments: actualArgs,
                ),
                builder: (_) => const EditMealScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String id, String text) async {
    await tester.scrollUntilVisible(
      input(id),
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.ensureVisible(input(id));
    await tester.enterText(input(id), text);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String id) =>
      tester.widget<TextFormField>(input(id)).controller!.text;
  Future<void> save(WidgetTester tester) async {
    await tester.tap(identified('edit-meal-save'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) =>
      captureWidget(tester, captureKey, name);

  for (final specs in [('60', '15', '15', '80'), ('200', '50', '100', '500')]) {
    testWidgets('save/reopen preserves independent specifications $specs', (
      tester,
    ) async {
      await pumpEditor(tester);
      await enter(tester, 'name', '薯片样例');
      await enter(tester, 'package-quantity', specs.$1);
      await enter(tester, 'serving-quantity', specs.$2);
      await enter(tester, 'nutrition-basis', specs.$3);
      await enter(tester, 'energy', specs.$4);
      await enter(tester, 'carbs', '8');
      await enter(tester, 'fat', '4');
      await enter(tester, 'protein', '3');
      await save(tester);
      expect(meals.saved, hasLength(1));
      final saved = meals.saved.single;
      expect(saved.mealQuantity, specs.$1);
      expect(saved.servingQuantity, double.parse(specs.$2));
      expect(saved.nutritionBasisQuantity, double.parse(specs.$3));
      await pumpEditor(tester, meal: MealEntity.fromMealDBO(saved));
      await tester.scrollUntilVisible(
        input('nutrition-basis'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(text(tester, 'package-quantity'), specs.$1);
      expect(text(tester, 'serving-quantity'), specs.$2);
      expect(text(tester, 'nutrition-basis'), specs.$3);
      await tester.scrollUntilVisible(
        input('energy'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(text(tester, 'energy'), specs.$4);
      await capture(tester, 'create-${specs.$1}-${specs.$2}-${specs.$3}');
      expect(tester.takeException(), isNull);
    });
  }

  for (final layout in [
    (320.0, 1.0, false),
    (390.0, 1.3, false),
    (390.0, 1.0, true),
  ]) {
    testWidgets('three quantity fields align at layout $layout', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        width: layout.$1,
        scale: layout.$2,
        dark: layout.$3,
      );
      await tester.scrollUntilVisible(
        input('nutrition-basis'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final rects = [
        'package-quantity',
        'serving-quantity',
        'nutrition-basis',
      ].map((id) => tester.getRect(input(id))).toList();
      for (final rect in rects.skip(1)) {
        expect(rect.top, rects.first.top);
        expect(rect.height, rects.first.height);
      }
      expect(identified('edit-meal-barcode-scan'), findsOneWidget);
      await capture(
        tester,
        'create-layout-${layout.$1}-${layout.$2}-${layout.$3}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid basis blocks save; unknown nutrients remain null', (
    tester,
  ) async {
    await pumpEditor(tester);
    await enter(tester, 'name', '自制食品');
    await enter(tester, 'nutrition-basis', '0');
    await save(tester);
    expect(meals.saved, isEmpty);
    await enter(tester, 'nutrition-basis', '15');
    await enter(tester, 'energy', '80');
    await enter(tester, 'carbs', '0');
    await save(tester);
    expect(
      meals.saved.single.nutriments.energyKcal100,
      closeTo(80 * 100 / 15, 1e-8),
    );
    expect(meals.saved.single.nutriments.carbohydrates100, 0);
    expect(meals.saved.single.nutriments.fat100, isNull);
  });

  testWidgets('simple editing never rescales hidden untouched nutrients', (
    tester,
  ) async {
    final creator = EditMealBloc(_Config(), meals, preferences);
    final original = creator.createNewMealEntity(
      MealEntity.empty(),
      '纤维样例',
      '',
      '60',
      '15',
      '100',
      'g',
      '500',
      '50',
      '20',
      '10',
      fiberText: '5',
      zincText: '2',
    );
    addTearDown(creator.close);
    await pumpEditor(tester, meal: original);
    await enter(tester, 'nutrition-basis', '15');
    await enter(tester, 'energy', '80');
    await save(tester);
    expect(meals.saved.single.nutriments.fiber100, 5);
    expect(meals.saved.single.nutriments.zinc100, 2);
  });

  testWidgets('advanced entries survive switching to simple before save', (
    tester,
  ) async {
    await pumpEditor(tester);
    await enter(tester, 'name', '完整营养样例');
    await enter(tester, 'package-quantity', '60');
    await enter(tester, 'serving-quantity', '15');
    await enter(tester, 'nutrition-basis', '15');
    await enter(tester, 'energy', '80');
    FocusManager.instance.primaryFocus?.unfocus();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('高级'));
    await tester.pumpAndSettle();
    const ids = [
      'fiber',
      'saturated-fat',
      'sugars',
      'sodium',
      'calcium',
      'iron',
      'potassium',
      'magnesium',
      'vitamin-d',
      'vitamin-b12',
      'monounsaturated-fat',
      'polyunsaturated-fat',
      'trans-fat',
      'cholesterol',
      'zinc',
      'phosphorus',
      'vitamin-a',
      'vitamin-c',
      'vitamin-b6',
      'niacin',
    ];
    for (var i = 0; i < ids.length; i++) {
      await enter(tester, ids[i], '${i + 1}');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('简单'));
    await tester.pumpAndSettle();
    await save(tester);
    final saved = meals.saved.single;
    expect(saved.nutritionBasisQuantity, 15);
    expect(saved.servingQuantity, 15);
    expect(saved.mealQuantity, '60');
    expect(saved.nutriments.zinc100, closeTo(15 * 100 / 15, 1e-8));
    expect(saved.nutriments.vitaminA100, closeTo(17 * 100 / 15, 1e-8));
    await pumpEditor(tester, meal: MealEntity.fromMealDBO(saved));
    await tester.tap(find.text('高级'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<CustomMealFormMode>>(
            find.byType(SegmentedButton<CustomMealFormMode>),
          )
          .selected,
      {CustomMealFormMode.advanced},
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < ids.length; i++) {
      await tester.scrollUntilVisible(
        input(ids[i]),
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      await tester.pumpAndSettle();
      expect(text(tester, ids[i]), '${i + 1}', reason: ids[i]);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('kJ entry saves kcal with the independent label basis', (
    tester,
  ) async {
    await pumpEditor(tester, kj: true);
    await enter(tester, 'name', '千焦样例');
    await enter(tester, 'nutrition-basis', '15');
    await enter(tester, 'energy', '334.72');
    await save(tester);
    expect(
      meals.saved.single.nutriments.energyKcal100,
      closeTo(80 * 100 / 15, 1e-8),
    );
  });
}
