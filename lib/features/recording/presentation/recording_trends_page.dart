import 'dart:math' as math;
import 'package:opennutritracker/features/recording/domain/recording_nutrient.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/recording/domain/recording_trends.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecordingTrendsPage extends StatefulWidget {
  const RecordingTrendsPage({super.key});
  @override
  State<RecordingTrendsPage> createState() => _RecordingTrendsPageState();
}

class _RecordingTrendsPageState extends State<RecordingTrendsPage> {
  List<IntakeEntity>? _intakes;
  int _offset = 0;
  int _days = 7;
  RecordingNutrient _nutrient = RecordingNutrient.energy;
  DateTime? _end;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await locator<GetConfigUsecase>().getConfig();
      final rows = await locator<IntakeRepository>().getAllIntakesDBO();
      if (!mounted) return;
      setState(() {
        _offset = DayBoundaryCalc.totalMinutesOf(
          config.dayStartOffsetHours,
          config.dayStartOffsetMinutes,
        );
        _end ??= DayBoundaryCalc.currentLogicalDayMinutes(_offset);
        _intakes = rows.map(IntakeEntity.fromIntakeDBO).toList();
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _energy(BuildContext context, RecordedNutrient value) =>
      value.value == null
      ? '—'
      : EnergyDisplay.formatRoundedWithUnit(context, value.value!);
  String _grams(RecordedNutrient value) =>
      value.value == null ? '—' : '${value.value!.toStringAsFixed(1)} g';
  String _partial(S s, RecordedNutrient value) =>
      value.partial ? ' · ${s.m4Partial}' : '';

  String _format(BuildContext context, RecordedNutrient n) =>
      _nutrient == RecordingNutrient.energy
      ? _energy(context, n)
      : n.value == null
      ? '—'
      : '${n.value!.toStringAsFixed(2)} ${_nutrient.unit}';

  Map<RecordingNutrient, String> _labels(S s) => {
    RecordingNutrient.energy: s.energyLabel,
    RecordingNutrient.protein: s.proteinLabel,
    RecordingNutrient.fat: s.fatLabel,
    RecordingNutrient.carbs: s.carbsLabel,
    RecordingNutrient.sugars: s.sugarLabel,
    RecordingNutrient.saturatedFat: s.saturatedFatLabel,
    RecordingNutrient.fiber: s.fiberLabel,
    RecordingNutrient.monounsaturatedFat: s.monounsaturatedFatLabel,
    RecordingNutrient.polyunsaturatedFat: s.polyunsaturatedFatLabel,
    RecordingNutrient.transFat: s.transFatLabel,
    RecordingNutrient.cholesterol: s.cholesterolLabel,
    RecordingNutrient.sodium: s.sodiumLabel,
    RecordingNutrient.potassium: s.potassiumLabel,
    RecordingNutrient.magnesium: s.magnesiumLabel,
    RecordingNutrient.calcium: s.calciumLabel,
    RecordingNutrient.iron: s.ironLabel,
    RecordingNutrient.zinc: s.zincLabel,
    RecordingNutrient.phosphorus: s.phosphorusLabel,
    RecordingNutrient.vitaminA: s.vitaminALabel,
    RecordingNutrient.vitaminC: s.vitaminCLabel,
    RecordingNutrient.vitaminD: s.vitaminDLabel,
    RecordingNutrient.vitaminB6: s.vitaminB6Label,
    RecordingNutrient.vitaminB12: s.vitaminB12Label,
    RecordingNutrient.niacin: s.niacinLabel,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rows = _intakes == null || _end == null
        ? <RecordingDayTotals>[]
        : recordingTrends(_intakes!, _end!, _days, _offset);
    final all = RecordingDayTotals(
      _end ?? DateTime.now(),
      rows.expand((r) => r.intakes).toList(),
    );
    final selected = all.nutrient(_nutrient);
    final labels = _labels(s);
    final maximum = rows.fold<double>(
      0,
      (m, r) => math.max(m, r.nutrient(_nutrient).value ?? 0),
    );
    final recorded = rows.where((r) => r.intakes.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: Text(s.trendsLabel)),
      body: SafeArea(
        top: false,
        child: _failed
            ? Center(
                child: Semantics(
                  identifier: 'trends-retry',
                  child: TextButton(
                    onPressed: _load,
                    child: Text(s.m4OperationFailed),
                  ),
                ),
              )
            : _intakes == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Semantics(
                      identifier: 'trends-period',
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 7, label: Text(s.m4SevenDays)),
                          ButtonSegment(value: 30, label: Text(s.m4ThirtyDays)),
                        ],
                        selected: {_days},
                        onSelectionChanged: (v) =>
                            setState(() => _days = v.first),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      identifier: 'trends-end-date',
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${s.m4PeriodEnd}: ${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_end!)}',
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _end!,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null && mounted) {
                            setState(() => _end = date);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(s.m4TrendsNote),
                    const SizedBox(height: 16),
                    Semantics(
                      identifier: 'trends-nutrient',
                      child: DropdownButtonFormField<RecordingNutrient>(
                        initialValue: _nutrient,
                        isExpanded: true,
                        items: [
                          for (final e in labels.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (n) => setState(() => _nutrient = n!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (recorded == 0)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.m4NoRecords),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${s.m4RecordedDays}: $recorded / $_days'),
                              const SizedBox(height: 12),
                              Text(
                                s.m4PeriodTotal,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${labels[_nutrient]}: ${_format(context, selected)}${_partial(s, selected)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${s.m4RecordedAverage}: ${_format(context, RecordedNutrient(selected.value == null ? null : selected.value! / recorded, selected.known, selected.records))}${_partial(s, selected)}',
                              ),
                              const SizedBox(height: 12),
                              for (final e in {
                                s.proteinLabel: all.protein,
                                s.fatLabel: all.fat,
                                s.carbsLabel: all.carbs,
                              }.entries)
                                Text(
                                  '${e.key}: ${_grams(e.value)}${_partial(s, e.value)}',
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      s.m4ChartNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // Text rows keep every date and value accessible at large font sizes.
                    Semantics(
                      identifier: 'trends-daily-list',
                      child: Column(
                        children: [
                          for (final r in rows.reversed)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      DateFormat.MMMd(
                                        Localizations.localeOf(
                                          context,
                                        ).toString(),
                                      ).format(r.day),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    if (r.intakes.isEmpty)
                                      Text(s.m4NoDayRecords)
                                    else ...[
                                      Text(
                                        '${labels[_nutrient]}: ${_format(context, r.nutrient(_nutrient))}${_partial(s, r.nutrient(_nutrient))}',
                                      ),
                                      if (r.nutrient(_nutrient).value !=
                                          null) ...[
                                        const SizedBox(height: 8),
                                        ExcludeSemantics(
                                          child: LinearProgressIndicator(
                                            value: maximum <= 0
                                                ? 0
                                                : (r
                                                              .nutrient(
                                                                _nutrient,
                                                              )
                                                              .value! /
                                                          maximum)
                                                      .clamp(0.0, 1.0),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
