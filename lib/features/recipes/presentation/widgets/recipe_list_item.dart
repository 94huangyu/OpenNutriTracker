import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecipeListItem extends StatelessWidget {
  final RecipeEntity recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  static const double _thumbSize = 44;

  const RecipeListItem({
    super.key,
    required this.recipe,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;

    final kcalPer100 = recipe.aggregatedNutrimentsPer100.energyKcal100;
    final totalKcal = (kcalPer100 ?? double.nan) * recipe.totalWeightG / 100;
    final energy = totalKcal.isFinite && totalKcal >= 0
        ? EnergyDisplay.formatRoundedWithUnit(context, totalKcal)
        : '— ${EnergyDisplay.unitLabel(context)}';
    final ingredientCount = recipe.ingredients.length;

    // Derive a thumbnail from the first ingredient that has one. Falls back
    // to a generic recipe icon when none of the ingredients carry imagery
    // (e.g. all-custom-meal recipes from the FDC source).
    final thumbnailUrl = recipe.ingredients
        .map((i) => i.snapshotMeal.thumbnailImageUrl)
        .firstWhere((url) => url != null && url.isNotEmpty, orElse: () => null);

    return FoodLibraryTile(
      title: recipe.name,
      detail:
          '${S.of(context).recipeIngredientCountLabel(ingredientCount)} · '
          '${S.of(context).libraryTotalEnergy(energy)}',
      leading: _buildLeading(context, palette, accent, thumbnailUrl),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: accent, size: 24)
          : Icon(
              Icons.chevron_right_rounded,
              color: palette.textMuted,
              size: 24,
            ),
      selected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildLeading(
    BuildContext context,
    AppPalette palette,
    Color accent,
    String? thumbnailUrl,
  ) {
    if (recipe.imagePath != null) {
      return _UserImageThumbnail(relativePath: recipe.imagePath!);
    }
    if (thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: Dimens.borderRadiusThumbnail,
        child: CachedNetworkImage(
          cacheManager: locator<CacheManager>(),
          fit: BoxFit.cover,
          width: _thumbSize,
          height: _thumbSize,
          imageUrl: thumbnailUrl,
          errorWidget: (context, url, error) => _fallbackThumb(palette, accent),
        ),
      );
    }
    return _fallbackThumb(palette, accent);
  }

  static Widget _fallbackThumb(AppPalette palette, Color accent) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: Dimens.borderRadiusThumbnail,
      ),
      child: Icon(Icons.menu_book_rounded, color: accent, size: 24),
    );
  }
}

class _UserImageThumbnail extends StatelessWidget {
  final String relativePath;

  const _UserImageThumbnail({required this.relativePath});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    return FutureBuilder<String>(
      future: UserImageStorage.absolutePath(relativePath),
      builder: (context, snapshot) {
        final fallback = RecipeListItem._fallbackThumb(palette, accent);
        if (!snapshot.hasData) return fallback;
        return ClipRRect(
          borderRadius: Dimens.borderRadiusThumbnail,
          child: Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            width: RecipeListItem._thumbSize,
            height: RecipeListItem._thumbSize,
            errorBuilder: (_, error, stack) => fallback,
          ),
        );
      },
    );
  }
}
