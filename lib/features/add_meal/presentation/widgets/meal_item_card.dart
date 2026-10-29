import 'package:opennutritracker/core/utils/food_unit_label.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/util/food_emoji_resolver.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealItemCard extends StatelessWidget {
  final VoidCallback? onReturn;
  final DateTime day;
  final AddMealType addMealType;
  final MealEntity mealEntity;
  final bool usesImperialUnits;
  final bool browseOnly;

  const MealItemCard({
    super.key,
    this.onReturn,
    required this.day,
    required this.mealEntity,
    required this.addMealType,
    required this.usesImperialUnits,
    this.browseOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final isRecipe = mealEntity.source == MealSourceEntity.recipe;
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
    // Colored emoji is reserved for FDC base-food items where the head
    // noun reliably identifies the food ("Milk, fluid, nonfat..." → milk).
    // OFF products are branded, so a head-noun match would often be
    // misleading; they keep the outline icon as a placeholder.
    final emoji =
        (mealEntity.thumbnailImageUrl == null &&
            mealEntity.source == MealSourceEntity.fdc)
        ? resolveFoodEmoji(mealEntity.name)
        : null;
    if (browseOnly) {
      return FoodLibraryTile(
        title: mealEntity.name ?? '?',
        brand: mealEntity.brands,
        detail: _nutritionSummary(context),
        leading: SizedBox.square(
          dimension: 44,
          child: FittedBox(
            child: _buildThumbnail(context, palette, accent, isRecipe, emoji),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: palette.textMuted,
          size: 24,
        ),
        onTap: () => _onItemPressed(context),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: Dimens.borderRadiusCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onItemPressed(context),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildThumbnail(context, palette, accent, isRecipe, emoji),
                  const SizedBox(width: Dimens.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTitle(context, palette),
                        if (!stacked) ...[
                          const SizedBox(height: Dimens.spacing4),
                          Text(
                            _nutritionSummary(context),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: Dimens.spacing4),
                          _buildSubtitle(context, palette, accent, isRecipe),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Dimens.spacing8),
                  if (!browseOnly)
                    Semantics(
                      identifier: 'meal-item-add',
                      child: IconButton(
                        tooltip: S.of(context).addLabel,
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 24),
                        onPressed: () => _onItemPressed(context),
                      ),
                    ),
                ],
              ),
              if (stacked) ...[
                const SizedBox(height: 8),
                Text(
                  _nutritionSummary(context),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                _buildSubtitle(context, palette, accent, isRecipe),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppPalette palette) =>
      AutoSizeText.rich(
        TextSpan(
          text: mealEntity.name ?? "?",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: palette.textStrong,
          ),
          children: [
            TextSpan(
              text: ' ${mealEntity.brands ?? ""}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textMuted),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  Widget _buildThumbnail(
    BuildContext context,
    AppPalette palette,
    Color accent,
    bool isRecipe,
    String? emoji,
  ) {
    if (mealEntity.localImagePath != null) {
      return MealThumbnail(meal: mealEntity, size: Dimens.mealThumb);
    }
    final radius = Dimens.borderRadiusThumbnail;
    if (mealEntity.thumbnailImageUrl != null) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          cacheManager: locator<CacheManager>(),
          fit: BoxFit.cover,
          width: Dimens.mealThumb,
          height: Dimens.mealThumb,
          imageUrl: mealEntity.thumbnailImageUrl ?? "",
        ),
      );
    }
    return Container(
      width: Dimens.mealThumb,
      height: Dimens.mealThumb,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: isRecipe ? accent.withValues(alpha: 0.16) : palette.surfaceMuted,
      ),
      child: emoji != null
          ? ExcludeSemantics(
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            )
          : Icon(
              isRecipe ? Icons.menu_book_rounded : Icons.restaurant_rounded,
              size: 26,
              color: isRecipe ? accent : palette.textMuted,
            ),
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    AppPalette palette,
    Color accent,
    bool isRecipe,
  ) {
    if (isRecipe &&
        !mealEntity.isFavorite &&
        !mealEntity.isPersonallyReviewed) {
      return _labelChip(
        context,
        S.of(context).additionalInfoLabelRecipe,
        background: accent.withValues(alpha: 0.16),
        foreground: accent,
      );
    }

    // Remote foods carry their database of origin; show it as a muted chip
    // (Open Food Facts, BLS, FDC SR Legacy...) so users can tell sources
    // apart. OFF products may additionally have a package quantity — keep
    // it visible next to the chip.
    final sourceLabel = _sourceLabel(context);
    final chip = sourceLabel != null
        ? Text(
            sourceLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
          )
        : null;
    final package = double.tryParse(mealEntity.mealQuantity ?? '');
    return Wrap(
      spacing: Dimens.spacing8,
      runSpacing: Dimens.spacing4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?chip,
        if (mealEntity.isFavorite)
          Icon(
            Icons.star_rounded,
            size: 18,
            semanticLabel: S.of(context).foodFavorites,
          ),
        if (mealEntity.isPersonallyReviewed)
          _labelChip(
            context,
            S.of(context).foodPersonallyReviewed,
            background: accent.withValues(alpha: 0.12),
            foreground: accent,
          ),
        if (package != null && package.isFinite && package > 0)
          Text(
            '${S.of(context).mealSizeLabel} ${_number(package)} '
            '${foodUnitLabel(S.of(context), mealEntity.mealUnit)}',
          ),
      ],
    );
  }

  String _number(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  String _nutritionSummary(BuildContext context) {
    final basis = mealEntity.effectiveNutritionBasis;
    final kcal100 = mealEntity.nutriments.energyKcal100;
    final energy = kcal100 != null && kcal100.isFinite && kcal100 >= 0
        ? EnergyDisplay.formatRoundedWithUnit(context, kcal100 * basis / 100)
        : '— ${EnergyDisplay.unitLabel(context)}';
    return '${S.of(context).customMealNutritionBasis(basis.toString().replaceFirst(RegExp(r"\.0$"), ""), foodUnitLabel(S.of(context), mealEntity.mealUnit))} · $energy';
  }

  /// Personal foods take precedence over their retained public reference.
  String? _sourceLabel(BuildContext context) {
    if (mealEntity.source == MealSourceEntity.custom) {
      return S.of(context).myFoodLabel;
    }
    if (mealEntity.source == MealSourceEntity.recipe) {
      return S.of(context).additionalInfoLabelRecipe;
    }
    final backendLabel = SPConst.foodSourceShortNames[mealEntity.backendSource];
    if (backendLabel != null) return backendLabel;
    if (mealEntity.source == MealSourceEntity.off) {
      return OFFConst.offSourceName;
    }
    if (mealEntity.source == MealSourceEntity.fdc) {
      return S.of(context).additionalInfoLabelFDC;
    }
    return S.of(context).additionalInfoLabelUnknown;
  }

  Widget _labelChip(
    BuildContext context,
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacing8,
        vertical: Dimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Dimens.borderRadiusS,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _onItemPressed(BuildContext context) {
    Navigator.of(context)
        .pushNamed(
          NavigationOptions.mealDetailRoute,
          arguments: MealDetailScreenArguments(
            mealEntity,
            addMealType.getIntakeType(),
            day,
            usesImperialUnits,
            browseOnly: browseOnly,
          ),
        )
        .then((_) => onReturn?.call());
  }
}
