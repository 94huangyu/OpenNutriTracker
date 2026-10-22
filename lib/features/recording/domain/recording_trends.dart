import 'package:opennutritracker/features/recording/domain/recording_nutrient.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';

class RecordedNutrient {
  final double? value;
  final int known;
  final int records;
  const RecordedNutrient(this.value, this.known, this.records);
  bool get partial => known > 0 && known < records;
}

class RecordingDayTotals {
  final DateTime day;
  final List<IntakeEntity> intakes;
  const RecordingDayTotals(this.day, this.intakes);
  RecordedNutrient sum(double? Function(IntakeEntity) perUnit) {
    var value = 0.0, known = 0;
    for (final intake in intakes) {
      final nutrient = perUnit(intake);
      if (nutrient == null) continue;
      final total = nutrient * intake.amount;
      if (!total.isFinite) continue;
      value += total;
      known++;
    }
    return RecordedNutrient(known == 0 ? null : value, known, intakes.length);
  }

  RecordedNutrient nutrient(RecordingNutrient field) => sum((i) {
    final value = field.per100(i.meal.nutriments);
    return value == null ? null : value / 100;
  });
  RecordedNutrient get energy => sum((i) => i.meal.nutriments.energyPerUnit);
  RecordedNutrient get protein => sum((i) => i.meal.nutriments.proteinsPerUnit);
  RecordedNutrient get fat => sum((i) => i.meal.nutriments.fatPerUnit);
  RecordedNutrient get carbs =>
      sum((i) => i.meal.nutriments.carbohydratesPerUnit);
}

List<RecordingDayTotals> recordingTrends(
  List<IntakeEntity> intakes,
  DateTime end,
  int days,
  int offsetMinutes,
) {
  final dates = <DateTime, List<IntakeEntity>>{
    for (var i = days - 1; i >= 0; i--)
      DateTime(end.year, end.month, end.day - i): [],
  };
  for (final intake in intakes) {
    final label = DayBoundaryCalc.storedMomentDayLabel(
      intake.dateTime,
      offsetMinutes,
    );
    dates[label]?.add(intake);
  }
  return [for (final e in dates.entries) RecordingDayTotals(e.key, e.value)];
}
