import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// Durable user choices, separate from expiring public search caches.
/// Never writes intakes or public records. Each row is a reviewed/saved snapshot.
class PersonalFoodDataSource extends ChangeNotifier {
  final Box<MealDBO> _box;
  PersonalFoodDataSource(this._box);

  List<MealEntity> getAll() => _box.values.map(MealEntity.fromMealDBO).toList();

  MealEntity apply(MealEntity meal) {
    final saved = _box.get(meal.personalKey);
    if (saved == null) {
      // A historical snapshot does not re-enable a removed personal choice.
      return meal.withPersonalState(isFavorite: false);
    }
    final personal = MealEntity.fromMealDBO(saved);
    final same = sameReviewContent(meal, personal);
    return meal.withPersonalState(
      isFavorite: personal.isFavorite,
      reviewSource: same ? personal.reviewSource : null,
      reviewNote: same ? personal.reviewNote : null,
      reviewedAt: same ? personal.reviewedAt : null,
    );
  }

  bool reviewIsOutdated(MealEntity meal) {
    final saved = _box.get(meal.personalKey);
    if (saved == null) return false;
    final personal = MealEntity.fromMealDBO(saved);
    return personal.isPersonallyReviewed && !sameReviewContent(meal, personal);
  }

  Future<MealEntity> setFavorite(MealEntity meal, bool favorite) async {
    final current = apply(meal);
    return _save(
      current.withPersonalState(
        isFavorite: favorite,
        reviewSource: current.reviewSource,
        reviewNote: current.reviewNote,
        reviewedAt: current.reviewedAt,
      ),
    );
  }

  Future<MealEntity> review(
    MealEntity meal,
    String source,
    String note, {
    DateTime? now,
  }) async {
    if (!MealEntity.reviewSources.contains(source) || note.trim().isEmpty) {
      throw ArgumentError('Review needs a source type and an explanation');
    }
    return _save(
      meal.withPersonalState(
        isFavorite: apply(meal).isFavorite,
        reviewSource: source,
        reviewNote: note.trim(),
        reviewedAt: DateTime.fromMillisecondsSinceEpoch(
          (now ?? DateTime.now()).millisecondsSinceEpoch,
          isUtc: true,
        ),
      ),
    );
  }

  Future<MealEntity> clearReview(MealEntity meal) =>
      _save(meal.withPersonalState(isFavorite: apply(meal).isFavorite));

  Future<MealEntity> _save(MealEntity meal) async {
    if (!meal.canSavePersonalState) {
      throw ArgumentError('Food has no stable identity');
    }
    // Keep an explicit cleared row so old snapshot metadata cannot revive it.
    await _box.put(meal.personalKey, MealDBO.fromMealEntity(meal));
    notifyListeners();
    return meal;
  }

  /// Preserve favorite, invalidate review on edited food data, migrate identity.
  Future<void> updateTemplate(MealEntity oldMeal, MealEntity updated) async {
    if (!_box.containsKey(oldMeal.personalKey)) return;
    final current = apply(oldMeal);
    final same = sameReviewContent(oldMeal, updated);
    await _save(
      updated.withPersonalState(
        isFavorite: current.isFavorite,
        reviewSource: same ? current.reviewSource : null,
        reviewNote: same ? current.reviewNote : null,
        reviewedAt: same ? current.reviewedAt : null,
      ),
    );
    if (oldMeal.personalKey != updated.personalKey) {
      await _box.delete(oldMeal.personalKey);
    }
  }

  Future<void> remove(MealEntity meal) async {
    await _box.delete(meal.personalKey);
    notifyListeners();
  }

  /// Imported evidence is personal documentation, never database certification.
  Future<void> importMeals(Iterable<MealDBO> meals) async {
    final rows = <String, MealDBO>{};
    for (final dbo in meals) {
      final meal = MealEntity.fromMealDBO(dbo);
      if (!meal.canSavePersonalState) {
        throw const FormatException('Personal food has no stable identity');
      }
      if ((meal.reviewSource != null ||
              meal.reviewNote != null ||
              meal.reviewedAt != null) &&
          !meal.isPersonallyReviewed) {
        throw const FormatException('Incomplete personal review evidence');
      }
      rows[meal.personalKey] = dbo;
    }
    await _box.putAll(rows);
    notifyListeners();
  }

  List<MealDBO> exportMeals() => _box.values.toList();

  /// Ignore transport/image/translation flags; compare food identity and data.
  static bool sameReviewContent(MealEntity a, MealEntity b) =>
      const DeepCollectionEquality().equals(
        _reviewContent(a),
        _reviewContent(b),
      );

  static List<Object?> _reviewContent(MealEntity meal) => [
    meal.personalKey,
    meal.name,
    meal.brands,
    meal.mealQuantity,
    meal.mealUnit,
    meal.servingQuantity,
    meal.servingUnit,
    meal.servingSize,
    meal.effectiveNutritionBasis,
    meal.originalSource,
    meal.originalCode,
    jsonDecode(jsonEncode(MealDBO.fromMealEntity(meal).nutriments.toJson())),
  ];
}
