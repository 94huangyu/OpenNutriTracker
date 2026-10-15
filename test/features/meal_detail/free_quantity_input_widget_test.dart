import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_bottom_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';

// Exercises the real intake controls without preset quantity chips.

class _FakeAddIntakeUsecase extends Fake implements AddIntakeUsecase {}

class _FakeAddTrackedDayUsecase extends Fake implements AddTrackedDayUsecase {}

class _FakeGetKcalGoalUsecase extends Fake implements GetKcalGoalUsecase {}

class _FakeGetMacroGoalUsecase extends Fake implements GetMacroGoalUsecase {}

class _FakeGetTrackedDayUsecase extends Fake implements GetTrackedDayUsecase {}

class _FakeProductsRepository extends Fake implements ProductsRepository {}

class _FakeRemoteSearchCacheDataSource extends Fake
    implements RemoteSearchCacheDataSource {}

MealDetailBloc _buildBloc() => MealDetailBloc(
  _FakeAddIntakeUsecase(),
  _FakeAddTrackedDayUsecase(),
  _FakeGetKcalGoalUsecase(),
  _FakeGetMacroGoalUsecase(),
  _FakeGetTrackedDayUsecase(),
  _FakeProductsRepository(),
  _FakeRemoteSearchCacheDataSource(),
);

const _nutriments = MealNutrimentsEntity(
  energyKcal100: 100,
  carbohydrates100: 10,
  fat100: 5,
  proteins100: 5,
  sugars100: 2,
  saturatedFat100: 1,
  fiber100: 1,
);

MealEntity _solidWithServing() => MealEntity(
  code: 'chip-widget-test',
  name: 'Test product',
  url: null,
  mealQuantity: null,
  mealUnit: 'g',
  servingQuantity: 30,
  servingUnit: 'g',
  servingSize: '30 g',
  nutriments: _nutriments,
  source: MealSourceEntity.off,
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required MealEntity product,
  required TextEditingController quantityController,
  required void Function(String?, String?) onChanged,
  String initialUnit = 'serving',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: MealDetailBottomSheet(
          product: product,
          day: DateTime(2026, 9, 13),
          intakeTypeEntity: IntakeTypeEntity.breakfast,
          quantityTextController: quantityController,
          mealDetailBloc: _buildBloc(),
          selectedUnit: initialUnit,
          onQuantityOrUnitChanged: onChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'free quantity input has no presets and keeps fractional servings',
    (tester) async {
      final controller = TextEditingController(text: '1');
      String? quantity;
      String? unit;
      await _pumpSheet(
        tester,
        product: _solidWithServing(),
        quantityController: controller,
        onChanged: (q, u) {
          quantity = q;
          unit = u;
        },
      );
      expect(find.byType(ActionChip), findsNothing);
      await tester.enterText(find.byType(TextFormField), '0.75');
      await tester.pumpAndSettle();
      expect(quantity, '0.75');
      expect(unit, 'serving');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('g').last);
      await tester.pumpAndSettle();
      expect(quantity, '0.75');
      expect(unit, 'g');
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('quantity and unit have aligned bounds at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: '0.75');
      await _pumpSheet(
        tester,
        product: _solidWithServing(),
        quantityController: controller,
        onChanged: (_, _) {},
      );
      final number = tester.getRect(find.byType(TextFormField));
      final unit = tester.getRect(find.byType(DropdownButtonFormField<String>));
      expect(number.top, unit.top);
      expect(number.height, unit.height);
      expect(tester.takeException(), isNull);
    });
  }
}
