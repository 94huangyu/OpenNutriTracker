import 'package:opennutritracker/core/utils/food_unit_label.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailNutrimentsTable extends StatelessWidget {
  final MealEntity product;
  final bool usesImperialUnits;
  final double? servingQuantity;
  final String? servingUnit;
  final bool showMicronutrients;

  const MealDetailNutrimentsTable({
    super.key,
    required this.product,
    required this.usesImperialUnits,
    this.servingQuantity,
    this.servingUnit,
    this.showMicronutrients = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textStyleNormal =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.textStrong) ??
            const TextStyle();
    final textStyleBold = Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600, color: palette.textMuted) ??
        const TextStyle();

    final headerText = usesImperialUnits && servingQuantity != null
        ? "${S.of(context).perServingLabel} (${servingQuantity!.roundToPrecision(1)}${foodUnitLabel(S.of(context), servingUnit)})"
        : S.of(context).per100gmlLabel;

    final n = product.nutriments;
    final hasMicroData = n.hasMicronutrientData;
    final showSection = showMicronutrients || hasMicroData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              S.of(context).nutritionInfoLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(headerText, style: textStyleBold),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          shadowed: false,
          borderRadius: 16,
          color: palette.surfaceMuted,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacing16,
            vertical: Dimens.spacing8,
          ),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(color: palette.border, width: Dimens.hairline),
            ),
            children: <TableRow>[
            _getNutrimentsTableRow(
              S.of(context).energyLabel,
              n.energyKcal100 == null ? '—' : EnergyDisplay.formatWithUnit(
                  context, _adjustValueForServing(n.energyKcal100!)),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              S.of(context).fatLabel,
              _formatMicroValue(n.fat100, 'g'),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              '   ${S.of(context).saturatedFatLabel}',
              _formatMicroValue(n.saturatedFat100, 'g'),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              S.of(context).carbohydrateLabel,
              _formatMicroValue(n.carbohydrates100, 'g'),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              '    ${S.of(context).sugarLabel}',
              _formatMicroValue(n.sugars100, 'g'),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              S.of(context).fiberLabel,
              _formatMicroValue(n.fiber100, 'g'),
              textStyleNormal,
            ),
            _getNutrimentsTableRow(
              S.of(context).proteinLabel,
              _formatMicroValue(n.proteins100, 'g'),
              textStyleNormal,
            ),
            ],
          ),
        ),
        if (showSection) ...[
          const SizedBox(height: Dimens.spacing8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                S.of(context).micronutrientsLabel,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              initiallyExpanded: hasMicroData,
              children: [
                AppCard(
                  shadowed: false,
                  borderRadius: 16,
                  color: palette.surfaceMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimens.spacing16,
                    vertical: Dimens.spacing8,
                  ),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside:
                          BorderSide(color: palette.border, width: Dimens.hairline),
                    ),
                    children: [
                    // Extended lipid profile
                    _microRow(
                      '   ${S.of(context).monounsaturatedFatLabel}',
                      n.monounsaturatedFat100,
                      'g',
                      textStyleNormal,
                    ),
                    _microRow(
                      '   ${S.of(context).polyunsaturatedFatLabel}',
                      n.polyunsaturatedFat100,
                      'g',
                      textStyleNormal,
                    ),
                    _microRow(
                      '   ${S.of(context).transFatLabel}',
                      n.transFat100,
                      'g',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).cholesterolLabel,
                      n.cholesterol100,
                      'mg',
                      textStyleNormal,
                    ),
                    // Minerals
                    _microRow(
                      S.of(context).sodiumLabel,
                      n.sodium100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).potassiumLabel,
                      n.potassium100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).magnesiumLabel,
                      n.magnesium100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).calciumLabel,
                      n.calcium100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).ironLabel,
                      n.iron100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).zincLabel,
                      n.zinc100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).phosphorusLabel,
                      n.phosphorus100,
                      'mg',
                      textStyleNormal,
                    ),
                    // Vitamins
                    _microRow(
                      S.of(context).vitaminALabel,
                      n.vitaminA100,
                      'µg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).vitaminCLabel,
                      n.vitaminC100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).vitaminDLabel,
                      n.vitaminD100,
                      'µg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).vitaminB6Label,
                      n.vitaminB6100,
                      'mg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).vitaminB12Label,
                      n.vitaminB12100,
                      'µg',
                      textStyleNormal,
                    ),
                    _microRow(
                      S.of(context).niacinLabel,
                      n.niacin100,
                      'mg',
                      textStyleNormal,
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double _adjustValueForServing(double value) {
    if (!usesImperialUnits || servingQuantity == null) {
      return value;
    }
    // Calculate per serving value based on 100g reference
    return (value * servingQuantity!) / 100;
  }

  String _formatMicroValue(double? valuePer100, String unit) {
    if (valuePer100 == null || !valuePer100.isFinite) return '—';
    final adjusted = _adjustValueForServing(valuePer100);
    return '${adjusted.roundToPrecision(2)}$unit';
  }

  TableRow _microRow(
    String label,
    double? valuePer100,
    String unit,
    TextStyle textStyle,
  ) {
    return _getNutrimentsTableRow(
      label,
      _formatMicroValue(valuePer100, unit),
      textStyle,
    );
  }

  TableRow _getNutrimentsTableRow(
    String label,
    String quantityString,
    TextStyle textStyle,
  ) {
    return TableRow(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spacing12),
          child: Text(label, style: textStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spacing12),
          child: Text(
            quantityString,
            style: textStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
