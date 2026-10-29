import 'package:opennutritracker/core/utils/food_unit_label.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_portion_summary.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/meal_detail/util/meal_quantity_converter.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Edits the record's snapshot; changing it never edits the food template.
class RecordIntakeSheet extends StatefulWidget {
  final IntakeEntity intake;
  final DateTime day;
  final CalendarDayBloc bloc;

  const RecordIntakeSheet({
    super.key,
    required this.intake,
    required this.day,
    required this.bloc,
  });

  @override
  State<RecordIntakeSheet> createState() => _RecordIntakeSheetState();
}

class _RecordIntakeSheetState extends State<RecordIntakeSheet> {
  late final TextEditingController _quantity;
  late String _unit;
  double? _baseAmount;
  bool _saving = false;
  String? _error;
  String get _baseUnit => widget.intake.meal.mealUnit ?? 'g/ml';
  bool get _hasServing {
    final serving = widget.intake.meal.scalableServingQuantity;
    return serving != null && serving.isFinite && serving > 0;
  }

  @override
  void initState() {
    super.initState();
    _baseAmount = widget.intake.amount.isFinite && widget.intake.amount > 0
        ? widget.intake.amount
        : null;
    _unit = widget.intake.unit == 'serving' && _hasServing
        ? 'serving'
        : _baseUnit;
    final value = _unit == 'serving'
        ? widget.intake.amount / widget.intake.meal.scalableServingQuantity!
        : widget.intake.amount;
    _quantity = TextEditingController(
      text: value.toString().replaceFirst(RegExp(r'\.0$'), ''),
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  double? _readAmount() {
    final value = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    final amount = convertQuantityToBaseUnit(value, _unit, widget.intake.meal);
    return amount.isFinite && amount > 0 ? amount : null;
  }

  double? get _amount => _baseAmount;

  void _switchUnit(String? unit) {
    if (unit == null || _baseAmount == null) return;
    setState(() {
      _unit = unit;
      final value = unit == 'serving'
          ? _baseAmount! / widget.intake.meal.scalableServingQuantity!
          : _baseAmount!;
      // Display conversion never becomes the source of truth for a later save.
      _quantity.text = value.toString().replaceFirst(RegExp(r'\.0$'), '');
      _error = null;
    });
  }

  Future<void> _save({bool delete = false, bool repeat = false}) async {
    if (_saving) return;
    final amount = _amount;
    if (!delete && (amount == null || !amount.isFinite)) {
      setState(() => _error = S.of(context).recordingPositiveQuantity);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    final bloc = widget.bloc;
    final intake = widget.intake;
    final day = widget.day;
    try {
      if (delete) {
        await widget.bloc.deleteIntakeItem(context, widget.intake, widget.day);
      } else if (repeat) {
        await bloc.repeatIntakeItem(intake, day, amount!, _unit);
      } else {
        await widget.bloc.updateIntakeItem(widget.intake.id, {
          'amount': amount!,
          'unit': _unit,
        }, widget.day);
      }
      if (mounted) Navigator.of(context).pop();
      if (delete) {
        showDeletedIntakeUndo(messenger, s, bloc, intake, day);
      } else if (repeat && messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(s.recordingRepeated)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.of(context).recordingSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    double? total(double? perUnit) =>
        _amount == null || perUnit == null ? null : _amount! * perUnit;
    final n = widget.intake.meal.nutriments;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.recordingEditTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Semantics(
                identifier: 'recording-cancel-intake',
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(s.dialogCancelLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.intake.meal.name ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            s.recordingDestination(
              MaterialLocalizations.of(context).formatCompactDate(widget.day),
              switch (widget.intake.type) {
                IntakeTypeEntity.breakfast => s.breakfastLabel,
                IntakeTypeEntity.lunch => s.lunchLabel,
                IntakeTypeEntity.dinner => s.dinnerLabel,
                IntakeTypeEntity.snack => s.snackLabel,
              },
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final quantity = Semantics(
                container: true,
                identifier: 'recording-edit-quantity',
                child: TextField(
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {
                    _baseAmount = _readAmount();
                    _error = null;
                  }),
                  decoration: InputDecoration(labelText: s.quantityLabel),
                ),
              );
              final unit = Semantics(
                container: true,
                identifier: 'recording-edit-unit',
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_unit),
                  initialValue: _unit,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s.unitLabel),
                  items: [
                    DropdownMenuItem(value: _baseUnit, child: Text(foodUnitLabel(s, _baseUnit))),
                    if (_hasServing)
                      DropdownMenuItem(
                        value: 'serving',
                        child: Text(s.servingLabel),
                      ),
                  ],
                  onChanged: _saving || _amount == null ? null : _switchUnit,
                ),
              );
              if (MediaQuery.textScalerOf(context).scale(14) > 19) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [quantity, const SizedBox(height: 16), unit],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: quantity),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: unit),
                ],
              );
            },
          ),
          if (_hasServing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '1 ${s.servingLabel} = '
                '${widget.intake.meal.scalableServingQuantity} ${foodUnitLabel(s, _baseUnit)}',
              ),
            ),
          const SizedBox(height: 16),
          FoodPortionSummary(
            caption:
                '${s.recordingThisPortion} · '
                '${_amount == null ? '—' : _amount!.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} ${foodUnitLabel(s, _baseUnit)}',
            kcal: total(n.energyPerUnit),
            carbs: total(n.carbohydratesPerUnit),
            protein: total(n.proteinsPerUnit),
            fat: total(n.fatPerUnit),
          ),
          const SizedBox(height: 8),
          Text(
            s.recordingSnapshotHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 20),
          Semantics(
            identifier: 'recording-save-intake',
            child: FilledButton(
              onPressed: _saving ? null : () => _save(),
              child: Text(s.recordingSave),
            ),
          ),
          const Divider(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 24,
            children: [
              Semantics(
                identifier: 'recording-repeat-intake',
                child: TextButton(
                  onPressed: _saving ? null : () => _save(repeat: true),
                  child: Text(s.recordingRepeat),
                ),
              ),
              Semantics(
                identifier: 'recording-delete-intake',
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _saving ? null : () => _save(delete: true),
                  child: Text(s.recordingDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showDeletedIntakeUndo(
  ScaffoldMessengerState messenger,
  S s,
  CalendarDayBloc bloc,
  IntakeEntity intake,
  DateTime day, {
  bool failed = false,
}) {
  if (!messenger.mounted) return;
  var restoring = false;
  messenger.showSnackBar(
    SnackBar(
      content: Text(failed ? s.recordingUndoFailed : s.recordingDeleted),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: s.recordingUndo,
        onPressed: () async {
          if (restoring) return;
          restoring = true;
          try {
            await bloc.restoreIntakeItem(intake, day);
            if (messenger.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(s.recordingRestored)),
              );
            }
          } catch (_) {
            showDeletedIntakeUndo(
              messenger,
              s,
              bloc,
              intake,
              day,
              failed: true,
            );
          }
        },
      ),
    ),
  );
}
