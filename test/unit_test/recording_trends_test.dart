import 'package:opennutritracker/features/recording/domain/recording_nutrient.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/recording/domain/recording_trends.dart';
import '../helpers/personal_food_fixture.dart';

void main() {
  IntakeEntity intake(
    String id,
    DateTime date, {
    bool unknown = false,
    double amount = 25,
  }) => IntakeEntity(
    id: id,
    unit: 'g',
    amount: amount,
    type: IntakeTypeEntity.lunch,
    meal: unknown ? MealEntity.empty() : food(),
    dateTime: date,
  );

  test(
    'day labels stay on their date; timestamps honor hours and minutes boundary',
    () {
      final rows = recordingTrends(
        [
          intake('label', DateTime.utc(2026, 10, 20)),
          intake('late', DateTime(2026, 10, 20, 4, 29)),
          intake('new', DateTime(2026, 10, 20, 4, 30)),
        ],
        DateTime(2026, 10, 20),
        7,
        270,
      );
      expect(rows.last.intakes.map((i) => i.id), ['label', 'new']);
      expect(rows[5].intakes.single.id, 'late');
      expect(rows.last.energy.value, 40);
      expect(rows.length, 7);
    },
  );
  test(
    'unknown, partial and recorded zero are distinct; empty days have no total',
    () {
      final rows = recordingTrends(
        [
          intake('known', DateTime(2026, 10, 20)),
          intake('unknown', DateTime(2026, 10, 20), unknown: true),
          intake('zero', DateTime(2026, 10, 19), amount: 0),
          intake('only-unknown', DateTime(2026, 10, 18), unknown: true),
        ],
        DateTime(2026, 10, 20),
        7,
        0,
      );
      expect(rows.last.energy.value, 20);
      expect(rows.last.energy.partial, true);
      expect(rows[5].energy.value, 0);
      expect(rows[5].energy.known, 1);
      expect(rows[4].energy.value, isNull);
      expect(rows[4].intakes.length, 1);
      expect(rows.first.intakes, isEmpty);
      expect(rows.first.energy.value, isNull);
    },
  );
  test(
    '30 day range respects month boundary and excludes future/outside entries',
    () {
      final rows = recordingTrends(
        [
          intake('first', DateTime(2026, 9, 21)),
          intake('outside', DateTime(2026, 9, 20)),
          intake('future', DateTime(2026, 10, 21)),
        ],
        DateTime(2026, 10, 20),
        30,
        0,
      );
      expect(rows.first.day, DateTime(2026, 9, 21));
      expect(rows.expand((r) => r.intakes).single.id, 'first');
    },
  );
  test(
    'every existing nutrient uses its stored unit and nullable per100 amount',
    () {
      const n = MealNutrimentsEntity(
        energyKcal100: 1,
        proteins100: 2,
        fat100: 3,
        carbohydrates100: 4,
        sugars100: 5,
        saturatedFat100: 6,
        fiber100: 7,
        monounsaturatedFat100: 8,
        polyunsaturatedFat100: 9,
        transFat100: 10,
        cholesterol100: 11,
        sodium100: 12,
        potassium100: 13,
        magnesium100: 14,
        calcium100: 15,
        iron100: 16,
        zinc100: 17,
        phosphorus100: 18,
        vitaminA100: 19,
        vitaminC100: 20,
        vitaminD100: 21,
        vitaminB6100: 22,
        vitaminB12100: 23,
        niacin100: 24,
      );
      for (var i = 0; i < RecordingNutrient.values.length; i++) {
        final field = RecordingNutrient.values[i];
        expect(field.per100(n), i + 1);
        expect(field.per100(MealNutrimentsEntity.empty()), isNull);
      }
      expect(RecordingNutrient.vitaminB12.unit, 'µg');
      expect(RecordingNutrient.sodium.unit, 'mg');
      final day = RecordingDayTotals(DateTime(2026, 10, 20), [
        intake('i', DateTime(2026, 10, 20)),
      ]);
      expect(day.nutrient(RecordingNutrient.sodium).value, 3);
      expect(day.nutrient(RecordingNutrient.vitaminA).value, 75);
    },
  );
}
