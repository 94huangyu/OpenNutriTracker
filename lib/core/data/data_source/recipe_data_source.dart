import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

class RecipeDataSource {
  final HiveDBProvider _db;

  final PersonalFoodDataSource? personalFoods;
  RecipeDataSource(this._db, {this.personalFoods});

  Box<RecipeDBO> get _recipeBox => _db.recipeBox;

  // Upsert by stable id. Recipe ids are uuids assigned at first save and
  // never change, so we can safely overwrite the matching record.
  Future<void> saveRecipe(RecipeDBO recipe) async {
    final existing = _recipeBox.values.cast<RecipeDBO?>().firstWhere(
          (r) => r?.id == recipe.id,
          orElse: () => null,
        );
    if (existing != null) {
      await _recipeBox.put(existing.key, recipe);
      await personalFoods?.updateTemplate(
        RecipeEntity.fromDBO(existing).toMealEntity(),
        RecipeEntity.fromDBO(recipe).toMealEntity(),
      );
    } else {
      await _recipeBox.add(recipe);
    }
  }

  List<RecipeDBO> getAllRecipes() => _recipeBox.values.toList();

  RecipeDBO? getRecipeById(String id) {
    for (final recipe in _recipeBox.values) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<void> deleteRecipe(String id) async {
    final toDelete = _recipeBox.values.where((r) => r.id == id).toList();
    for (final recipe in toDelete) {
      await recipe.delete();
      await personalFoods?.remove(RecipeEntity.fromDBO(recipe).toMealEntity());
    }
  }
}
