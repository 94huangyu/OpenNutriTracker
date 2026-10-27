import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/recording/presentation/widgets/record_intake_sheet.dart';
import 'package:opennutritracker/features/recording/presentation/widgets/recording_nutrient_summary.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecordingMealPage extends StatefulWidget {
  final DateTime day;
  final AddMealType type;
  final CalendarDayBloc bloc;
  const RecordingMealPage({
    super.key,
    required this.day,
    required this.type,
    required this.bloc,
  });

  @override
  State<RecordingMealPage> createState() => _RecordingMealPageState();
}

class _RecordingMealPageState extends State<RecordingMealPage> {
  bool _editing = false;
  bool _busy = false;
  final _selected = <String>{};

  List<IntakeEntity> _items(CalendarDayLoaded state) => [
    state.breakfastIntakeList,
    state.lunchIntakeList,
    state.dinnerIntakeList,
    state.snackIntakeList,
  ][widget.type.index];

  Future<void> _change(List<IntakeEntity> items, {required bool copy}) async {
    final selected = items.where((i) => _selected.contains(i.id)).toList();
    if (selected.isEmpty || _busy) return;
    final s = S.of(context);
    DateTime targetDay = widget.day;
    AddMealType targetType = widget.type;
    if (copy) {
      final destination = await showDialog<(DateTime, AddMealType)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(s.recordingCopyDestination),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    identifier: 'recording-copy-date',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        DateFormat.yMd(
                          Localizations.localeOf(context).toString(),
                        ).format(targetDay),
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: targetDay,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && context.mounted) {
                          update(() => targetDay = date);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'recording-copy-meal',
                    child: DropdownButtonFormField<AddMealType>(
                      initialValue: targetType,
                      isExpanded: true,
                      items: [
                        for (final type in AddMealType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.getTypeName(context)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) update(() => targetType = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(s.dialogCancelLabel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, (targetDay, targetType)),
                child: Text(s.copyActionLabel),
              ),
            ],
          ),
        ),
      );
      if (destination == null || !mounted) return;
      targetDay = destination.$1;
      targetType = destination.$2;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.recordingDeleteSelectedQuestion),
          content: Text(s.selectionCountLabel(selected.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.dialogCancelLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.dialogDeleteLabel),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (copy) {
        await widget.bloc.copySelectedIntakes(
          selected,
          targetDay,
          targetType.getIntakeType(),
        );
      } else {
        await widget.bloc.deleteSelectedIntakes(selected, widget.day);
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _editing = false;
      });
      widget.bloc.add(LoadCalendarDayEvent(widget.day));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy
                ? '${s.recordingCopyComplete} · ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(targetDay)} · ${targetType.getTypeName(context)}'
                : s.recordingDeleted,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.recordingSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(widget.day);
    return PopScope(
      canPop: !_busy,
      child: BlocBuilder<CalendarDayBloc, CalendarDayState>(
        bloc: widget.bloc,
        builder: (context, state) {
          final items = state is CalendarDayLoaded
              ? _items(state)
              : <IntakeEntity>[];
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.type.getTypeName(context)),
              actions: [
                Semantics(
                  identifier: 'recording-meal-edit',
                  child: TextButton(
                    onPressed: _busy || state is! CalendarDayLoaded
                        ? null
                        : () => setState(() {
                            _editing = !_editing;
                            _selected.clear();
                          }),
                    child: Text(
                      _editing ? s.dialogCancelLabel : s.recordingEdit,
                    ),
                  ),
                ),
              ],
            ),
            body: state is! CalendarDayLoaded
                ? const Center(child: CircularProgressIndicator())
                : Semantics(
                    identifier: 'recording-meal-detail',
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          date,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        RecordingNutrientSummary(items: items),
                        const SizedBox(height: 20),
                        if (_editing)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.selectionCountLabel(_selected.length),
                                ),
                              ),
                              Semantics(
                                identifier: 'recording-select-all',
                                child: TextButton(
                                  onPressed: _busy || items.isEmpty
                                      ? null
                                      : () => setState(() {
                                          if (_selected.length ==
                                              items.length) {
                                            _selected.clear();
                                          } else {
                                            _selected.addAll(
                                              items.map((i) => i.id),
                                            );
                                          }
                                        }),
                                  child: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).selectAllButtonLabel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(s.recordingNotRecorded),
                          ),
                        AppCard(
                          shadowed: false,
                          borderRadius: 16,
                          child: Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                _record(items[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            bottomNavigationBar: !_editing
                ? null
                : SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Semantics(
                          identifier: 'recording-delete-selected',
                          child: OutlinedButton.icon(
                            onPressed: _selected.isEmpty || _busy
                                ? null
                                : () => _change(items, copy: false),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(s.dialogDeleteLabel),
                          ),
                        ),
                        Semantics(
                          identifier: 'recording-copy-selected',
                          child: FilledButton.icon(
                            onPressed: _selected.isEmpty || _busy
                                ? null
                                : () => _change(items, copy: true),
                            icon: const Icon(Icons.copy_outlined),
                            label: Text(s.copyActionLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _record(IntakeEntity item) {
    final s = S.of(context);
    final serving = item.meal.scalableServingQuantity;
    final usesServing =
        item.unit == 'serving' &&
        serving != null &&
        serving.isFinite &&
        serving > 0;
    final quantity = usesServing ? item.amount / serving : item.amount;
    final unit = usesServing ? s.servingLabel : (item.meal.mealUnit ?? 'g/ml');
    return InkWell(
      key: ValueKey(item.id),
      onTap: _busy
          ? null
          : () async {
              if (_editing) {
                setState(() {
                  if (!_selected.add(item.id)) _selected.remove(item.id);
                });
              } else {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => RecordIntakeSheet(
                    intake: item,
                    day: widget.day,
                    bloc: widget.bloc,
                  ),
                );
                if (mounted) widget.bloc.add(LoadCalendarDayEvent(widget.day));
              }
            },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  _selected.contains(item.id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.meal.name ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${quantity.toStringAsFixed(2).replaceFirst(RegExp(r"\.?0+$"), "")} $unit · ${EnergyDisplay.formatRoundedWithUnit(context, item.totalKcal)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.carbsLabel} ${item.totalCarbsGram.toStringAsFixed(1)} g · ${s.proteinLabel} ${item.totalProteinsGram.toStringAsFixed(1)} g · ${s.fatLabel} ${item.totalFatsGram.toStringAsFixed(1)} g',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
