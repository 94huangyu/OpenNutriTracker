import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class CustomMealDataSource {
  final HiveDBProvider _db;

  CustomMealDataSource(this._db);

  Box<MealDBO> get _customMealBox => _db.customMealBox;

  Future<void> saveCustomMeal(MealDBO mealDBO) async {
    final existing = _customMealBox.values.cast<MealDBO?>().firstWhere(
        (m) =>
            (mealDBO.code != null && m?.code == mealDBO.code) ||
            (mealDBO.code == null && m?.name == mealDBO.name),
        orElse: () => null);
    if (existing != null) {
      await _customMealBox.put(existing.key, mealDBO);
    } else {
      await _customMealBox.add(mealDBO);
    }
  }

  List<MealDBO> getAllCustomMeals() => _customMealBox.values.toList();

  /// Keep the same Hive row when editing its name or barcode.
  /// A barcode owned by another food must never overwrite that food.
  Future<bool> updateCustomMeal(
    MealDBO updated, {
    String? originalCode,
    String? originalName,
  }) async {
    final previous = _customMealBox.values.cast<MealDBO?>().firstWhere(
      (meal) => originalCode != null
          ? meal?.code == originalCode
          : originalName != null &&
                meal?.code == null &&
                meal?.name == originalName,
      orElse: () => null,
    );
    if (_customMealBox.values.any(
      (meal) =>
          meal.key != previous?.key &&
          (updated.code != null
              ? meal.code == updated.code
              : meal.name == updated.name),
    )) {
      return false;
    }
    if (previous == null) {
      await _customMealBox.add(updated);
    } else {
      await _customMealBox.put(previous.key, updated);
    }
    return true;
  }

  Future<void> deleteCustomMeal(String mealKey) async {
    final toDelete = _customMealBox.values
        .where((m) => (m.code ?? m.name) == mealKey)
        .toList();
    for (final meal in toDelete) {
      await meal.delete();
    }
  }
}
