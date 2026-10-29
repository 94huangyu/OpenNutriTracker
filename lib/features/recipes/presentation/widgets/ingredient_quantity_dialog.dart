import 'package:opennutritracker/core/utils/food_unit_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class IngredientQuantitySelection {
  final double amount;
  final String unit;
  const IngredientQuantitySelection({required this.amount, required this.unit});
}

/// Modal bottom sheet that asks for the amount + unit of an ingredient.
/// Returns an [IngredientQuantitySelection] or null if cancelled.
Future<IngredientQuantitySelection?> showIngredientQuantityDialog(
  BuildContext context, {
  required MealEntity meal,
  double? initialAmount,
  String? initialUnit,
}) {
  return showModalBottomSheet<IngredientQuantitySelection>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _IngredientQuantitySheet(
      meal: meal,
      initialAmount: initialAmount,
      initialUnit: initialUnit,
    ),
  );
}

class _IngredientQuantitySheet extends StatefulWidget {
  final MealEntity meal;
  final double? initialAmount;
  final String? initialUnit;

  const _IngredientQuantitySheet({
    required this.meal,
    this.initialAmount,
    this.initialUnit,
  });

  @override
  State<_IngredientQuantitySheet> createState() =>
      _IngredientQuantitySheetState();
}

class _IngredientQuantitySheetState extends State<_IngredientQuantitySheet> {
  late TextEditingController _amountController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toString()
          : '',
    );
    _unit = widget.initialUnit ?? _defaultUnit(widget.meal);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _defaultUnit(MealEntity meal) {
    if (meal.hasServingValues) return 'serving';
    if (meal.isLiquid) return 'ml';
    return 'g';
  }

  List<DropdownMenuItem<String>> _unitItems(BuildContext context) {
    final items = <DropdownMenuItem<String>>[];
    if (widget.meal.hasServingValues) {
      items.add(_unitItem('serving'));
    }
    if (widget.meal.isSolid ||
        (!widget.meal.isLiquid && !widget.meal.isSolid)) {
      items.add(_unitItem('g'));
      items.add(_unitItem('kg'));
      items.add(_unitItem('oz'));
    }
    if (widget.meal.isLiquid ||
        (!widget.meal.isLiquid && !widget.meal.isSolid)) {
      items.add(_unitItem('ml'));
      items.add(_unitItem('l'));
      items.add(_unitItem('fl.oz'));
    }
    return items;
  }

  DropdownMenuItem<String> _unitItem(String unit) {
    return DropdownMenuItem(
      value: unit,
      child: Text(
        foodUnitLabel(S.of(context), unit),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final fieldBorder = OutlineInputBorder(
      borderRadius: Dimens.borderRadiusControl,
      borderSide: BorderSide(color: palette.border, width: Dimens.hairline),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacing24,
            Dimens.spacing24,
            Dimens.spacing24,
            Dimens.spacing16,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Dimens.radiusModal),
              topRight: Radius.circular(Dimens.radiusModal),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.spacing16),
              Text(
                widget.meal.name ?? '?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Dimens.spacing16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final amountField = Semantics(
                    identifier: 'recipe-ingredient-amount',
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+([.,]\d{0,2})?$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: S.of(context).recipeIngredientAmountLabel,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                      ),
                    ),
                  );
                  final unitField = Semantics(
                    identifier: 'recipe-ingredient-unit',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: _unit,
                      borderRadius: Dimens.borderRadiusControl,
                      decoration: InputDecoration(
                        labelText: S.of(context).recipeIngredientUnitLabel,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                      ),
                      items: _unitItems(context),
                      onChanged: (value) {
                        if (value != null) setState(() => _unit = value);
                      },
                    ),
                  );
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(16) > 22) {
                    return Column(
                      children: [
                        amountField,
                        const SizedBox(height: 12),
                        unitField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: amountField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: unitField),
                    ],
                  );
                },
              ),
              const SizedBox(height: Dimens.spacing16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimens.spacing16,
                    ),
                    shape: Dimens.shapeControl,
                  ),
                  onPressed: _onConfirm,
                  child: Text(S.of(context).addLabel),
                ),
              ),
              const SizedBox(height: Dimens.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    final raw = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pop(IngredientQuantitySelection(amount: amount, unit: _unit));
  }
}
