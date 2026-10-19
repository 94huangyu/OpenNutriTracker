import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
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
  bool _saving = false;
  String? _error;
  String get _baseUnit => widget.intake.meal.mealUnit ?? 'g/ml';
  bool get _hasServing => (widget.intake.meal.scalableServingQuantity ?? 0) > 0;

  @override
  void initState() {
    super.initState();
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

  double? get _amount {
    final value = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) return null;
    return convertQuantityToBaseUnit(value, _unit, widget.intake.meal);
  }

  Future<void> _save({bool delete = false}) async {
    final amount = _amount;
    if (!delete && (amount == null || !amount.isFinite)) {
      setState(() => _error = S.of(context).recordingPositiveQuantity);
      return;
    }
    setState(() => _saving = true);
    try {
      if (delete) {
        await widget.bloc.deleteIntakeItem(context, widget.intake, widget.day);
      } else {
        await widget.bloc.updateIntakeItem(widget.intake.id, {
          'amount': amount!,
          'unit': _unit,
        }, widget.day);
      }
      if (mounted) Navigator.of(context).pop();
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
    final height = 32 + MediaQuery.textScalerOf(context).scale(16) * 1.5;
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
          Text(
            widget.intake.meal.name ?? '',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: height,
                  child: Semantics(
                    container: true,
                    identifier: 'recording-edit-quantity',
                    child: TextField(
                      controller: _quantity,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(labelText: s.quantityLabel),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: height,
                  child: Semantics(
                    container: true,
                    identifier: 'recording-edit-unit',
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.unitLabel),
                      items: [
                        DropdownMenuItem(
                          value: _baseUnit,
                          child: Text(_baseUnit),
                        ),
                        if (_hasServing)
                          DropdownMenuItem(
                            value: 'serving',
                            child: Text(s.servingLabel),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _unit = value!;
                              _error = null;
                            }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hasServing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '1 ${s.servingLabel} = '
                '${widget.intake.meal.scalableServingQuantity} $_baseUnit',
              ),
            ),
          const SizedBox(height: 16),
          if (_amount != null)
            Text(
              EnergyDisplay.formatRoundedWithUnit(
                context,
                _amount! * (widget.intake.meal.nutriments.energyPerUnit ?? 0),
              ),
              style: Theme.of(context).textTheme.headlineSmall,
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
          Semantics(
            identifier: 'recording-delete-intake',
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(s.recordingDeleteQuestion),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(s.dialogCancelLabel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(s.recordingDelete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await _save(delete: true);
                      }
                    },
              child: Text(s.recordingDelete),
            ),
          ),
        ],
      ),
    );
  }
}
