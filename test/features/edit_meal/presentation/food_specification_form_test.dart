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
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
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
  final originals = <String?>[];
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
    originals.add(originalCode);
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
  late EnergyUnitProvider energyPreference;
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

  Future<void> selectEnergyUnit(WidgetTester tester, bool kj) async {
    final unit = find.byType(DropdownButtonFormField<bool>);
    await tester.scrollUntilVisible(
      unit,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await Scrollable.ensureVisible(tester.element(unit), alignment: .25);
    await tester.pumpAndSettle();
    if (tester.widget<DropdownButtonFormField<bool>>(unit).initialValue == kj) {
      return;
    }
    expect(
      tester.getRect(unit).bottom,
      lessThan(tester.getRect(identified('edit-meal-save')).top),
    );
    await tester.tap(unit);
    await tester.pumpAndSettle();
    await tester.tap(find.text(kj ? 'kJ' : 'kcal').last);
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    MealEntity? meal,
    double width = 390,
    double scale = 1,
    bool dark = false,
    bool kj = false,
    bool useDefaultInput = false,
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
          lazy: false,
          create: (_) =>
              energyPreference = EnergyUnitProvider(usesKilojoules: kj),
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
    if (!useDefaultInput) await selectEnergyUnit(tester, kj);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
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

  testWidgets(
    'public correction saves personal template without claiming ownership of an old custom row',
    (tester) async {
      final public = MealEntity(
        code: '12345678',
        name: '公共薯片',
        url: 'https://world.openfoodfacts.org/product/12345678',
        mealQuantity: '60',
        mealUnit: 'g',
        servingQuantity: 15,
        servingUnit: 'g',
        servingSize: '',
        source: MealSourceEntity.off,
        nutriments: MealNutrimentsEntity.empty(),
      );
      await pumpEditor(tester, meal: public);
      await enter(tester, 'nutrition-basis', '15');
      await enter(tester, 'energy', '80');
      await save(tester);
      expect(meals.saved.single.source, MealSourceDBO.custom);
      expect(meals.saved.single.code, '12345678');
      expect(meals.saved.single.url, public.url);
      expect(
        meals.saved.single.nutriments.energyKcal100,
        closeTo(80 / 15 * 100, 1e-9),
      );
      expect(meals.originals.single, isNull);
      expect(public.source, MealSourceEntity.off);
      expect(public.nutriments.energyKcal100, isNull);
    },
  );

  testWidgets('bottom save stays above keyboard and validation messages', (
    tester,
  ) async {
    await pumpEditor(tester);
    await save(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    var button = tester.getRect(identified('edit-meal-save'));
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(button.top),
    );
    await tester.enterText(input('name'), '键盘验证');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    button = tester.getRect(identified('edit-meal-save'));
    expect(button.bottom, lessThanOrEqualTo(600));
    await capture(tester, 'food-editor-keyboard-save');
    await tester.tap(identified('edit-meal-save'));
    await tester.pumpAndSettle();
    expect(meals.saved, hasLength(1));
  });

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
    (390.0, 1.0, false),
    (320.0, 1.6, false),
    (390.0, 1.3, false),
    (390.0, 2.0, true),
  ]) {
    testWidgets(
      'specifications reflow and nutrition basis is separate at $layout',
      (tester) async {
        await pumpEditor(
          tester,
          width: layout.$1,
          scale: layout.$2,
          dark: layout.$3,
        );
        await tester.scrollUntilVisible(
          identified('edit-meal-barcode-scan'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(identified('edit-meal-barcode-scan'), findsOneWidget);
        await tester.scrollUntilVisible(
          input('nutrition-basis'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(
          (position.pixels - 72 * layout.$2).clamp(0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        final rects = [
          'package-quantity',
          'serving-quantity',
          'nutrition-basis',
        ].map((id) => tester.getRect(input(id))).toList();
        if (layout.$1 >= 344 && layout.$2 * 14 <= 18) {
          expect(rects[1].top, rects[0].top);
          expect(rects[1].width, rects[0].width);
        } else {
          expect(rects[1].top, greaterThan(rects[0].bottom));
        }
        expect(rects[2].top, greaterThan(rects[1].bottom));
        await capture(
          tester,
          'create-layout-${layout.$1}-${layout.$2}-${layout.$3}',
        );
        expect(tester.takeException(), isNull);
      },
    );
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
      if ([3, 9, 19].contains(i)) {
        await capture(tester, 'advanced-editor-section-$i');
      }
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
  testWidgets(
    'new kJ input ignores global display changes and saves kcal once',
    (tester) async {
      await pumpEditor(tester, useDefaultInput: true);
      await enter(tester, 'name', '独立千焦输入');
      await enter(tester, 'energy', '2000');
      expect(
        tester
            .widget<DropdownButtonFormField<bool>>(
              find.byType(DropdownButtonFormField<bool>),
            )
            .initialValue,
        isTrue,
      );
      energyPreference.updateUsesKilojoules(true);
      await tester.pumpAndSettle();
      energyPreference.updateUsesKilojoules(false);
      await tester.pumpAndSettle();
      expect(text(tester, 'energy'), '2000');
      expect(find.textContaining('478.0'), findsOneWidget);
      await capture(tester, 'create-independent-kj-2000');
      await save(tester);
      expect(
        meals.saved.single.nutriments.energyKcal100,
        closeTo(2000 / 4.184, 1e-10),
      );
      await pumpEditor(
        tester,
        meal: MealEntity.fromMealDBO(meals.saved.single),
        kj: true,
        useDefaultInput: true,
      );
      await tester.scrollUntilVisible(
        input('energy'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<bool>>(
              find.byType(DropdownButtonFormField<bool>),
            )
            .initialValue,
        isFalse,
      );
      expect(double.parse(text(tester, 'energy')), closeTo(2000 / 4.184, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local unit round trips preserve untouched stored precision', (
    tester,
  ) async {
    final creator = EditMealBloc(_Config(), meals, preferences);
    const kcal = 123.456789012345;
    final original = creator.createNewMealEntity(
      MealEntity.empty(),
      '原始精度',
      '',
      '200',
      '30',
      '100',
      'g',
      '$kcal',
      '0',
      '0',
      '0',
    );
    addTearDown(creator.close);
    await pumpEditor(tester, meal: original, useDefaultInput: true);
    for (var i = 0; i < 5; i++) {
      await selectEnergyUnit(tester, true);
      await selectEnergyUnit(tester, false);
    }
    await save(tester);
    expect(meals.saved.single.nutriments.energyKcal100, kcal);
  });

  testWidgets('empty and zero energy survive local unit changes separately', (
    tester,
  ) async {
    await pumpEditor(tester, useDefaultInput: true);
    await enter(tester, 'name', '未知能量');
    await selectEnergyUnit(tester, false);
    await save(tester);
    expect(meals.saved.single.nutriments.energyKcal100, isNull);
    await pumpEditor(tester, useDefaultInput: true);
    await enter(tester, 'name', '零能量');
    await enter(tester, 'energy', '0');
    await selectEnergyUnit(tester, false);
    await selectEnergyUnit(tester, true);
    await save(tester);
    expect(meals.saved.last.nutriments.energyKcal100, 0);
  });
}
