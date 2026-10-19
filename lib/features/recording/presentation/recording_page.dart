import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/recording/presentation/recording_settings.dart';
import 'package:opennutritracker/features/recording/presentation/widgets/record_intake_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with WidgetsBindingObserver {
  late final CalendarDayBloc _bloc;
  DateTime? _day;
  final _expanded = <AddMealType>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc = locator<CalendarDayBloc>();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    _selectDay(
      DayBoundaryCalc.currentLogicalDayLabel(
        config.dayStartOffsetHours,
        config.dayStartOffsetMinutes,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _day != null) {
      _bloc.add(LoadCalendarDayEvent(_day!));
    }
  }

  void _selectDay(DateTime day) {
    setState(() => _day = DateUtils.dateOnly(day));
    _bloc.add(LoadCalendarDayEvent(_day!));
  }

  Future<void> _add(AddMealType type) async {
    await Navigator.of(context).pushNamed(
      NavigationOptions.addMealRoute,
      arguments: AddMealScreenArguments(type, _day!),
    );
    if (mounted) _bloc.add(LoadCalendarDayEvent(_day!));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.recordingTitle),
        actions: [
          Semantics(
            identifier: 'recording-food-library',
            child: IconButton(
              tooltip: s.recipesLabel,
              icon: const Icon(Icons.kitchen_outlined),
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(NavigationOptions.recipesRoute),
            ),
          ),
          Semantics(
            identifier: 'recording-settings',
            child: IconButton(
              tooltip: s.settingsLabel,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecordingSettings(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _day == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _dateBar(context),
                  Expanded(
                    child: BlocBuilder<CalendarDayBloc, CalendarDayState>(
                      bloc: _bloc,
                      builder: (context, state) {
                        if (state is! CalendarDayLoaded) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final groups = [
                          state.breakfastIntakeList,
                          state.lunchIntakeList,
                          state.dinnerIntakeList,
                          state.snackIntakeList,
                        ];
                        final all = groups.expand((items) => items).toList();
                        return RefreshIndicator(
                          onRefresh: () async {
                            final loaded = _bloc.stream.firstWhere(
                              (state) => state is CalendarDayLoaded,
                            );
                            _bloc.add(LoadCalendarDayEvent(_day!));
                            await loaded;
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              _summary(context, all),
                              const SizedBox(height: 20),
                              for (var i = 0; i < groups.length; i++)
                                _meal(
                                  context,
                                  AddMealType.values[i],
                                  groups[i],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _dateBar(BuildContext context) {
    return Row(
      children: [
        Semantics(
          identifier: 'recording-previous-day',
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            onPressed: () => _selectDay(DateUtils.addDaysToDate(_day!, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
        ),
        Expanded(
          child: Semantics(
            container: true,
            identifier: 'recording-date',
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(_day!),
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _day!,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) _selectDay(date);
              },
            ),
          ),
        ),
        Semantics(
          identifier: 'recording-next-day',
          child: IconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            onPressed: () => _selectDay(DateUtils.addDaysToDate(_day!, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ),
        Semantics(
          identifier: 'recording-today',
          child: TextButton(
            onPressed: _loadToday,
            child: Text(MaterialLocalizations.of(context).currentDateLabel),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, List<IntakeEntity> all) {
    final s = S.of(context);
    double sum(double Function(IntakeEntity) get) =>
        all.fold(0, (value, intake) => value + get(intake));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.recordingConsumed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              EnergyDisplay.formatRoundedWithUnit(
                context,
                sum((i) => i.totalKcal),
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _macro(s.proteinLabel, sum((i) => i.totalProteinsGram)),
                _macro(s.fatLabel, sum((i) => i.totalFatsGram)),
                _macro(s.carbsLabel, sum((i) => i.totalCarbsGram)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _macro(String name, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name),
      Text(
        '${value.toStringAsFixed(1)} g',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );

  Widget _meal(
    BuildContext context,
    AddMealType type,
    List<IntakeEntity> items,
  ) {
    final expanded = _expanded.contains(type);
    final total = items.fold<double>(0, (v, item) => v + item.totalKcal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    identifier: 'recording-meal-${type.name}',
                    child: ListTile(
                      onTap: () => setState(
                        () => expanded
                            ? _expanded.remove(type)
                            : _expanded.add(type),
                      ),
                      title: Text(
                        type.getTypeName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        EnergyDisplay.formatRoundedWithUnit(context, total),
                      ),
                      trailing: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  identifier: 'recording-add-${type.name}',
                  child: IconButton(
                    onPressed: () => _add(type),
                    tooltip: S.of(context).addLabel,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (expanded) ...[
              const Divider(height: 1),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(S.of(context).recordingEmptyMeal),
                ),
              Semantics(
                identifier: 'recording-intakes-${type.name}',
                child: Column(
                  children: [
                    for (final item in items)
                      IntakeCard(
                        key: ValueKey(item.id),
                        intake: item,
                        firstListElement: item == items.first,
                        usesImperialUnits: false,
                        onItemTapped: (context, intake, _) async {
                          await showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => RecordIntakeSheet(
                              intake: intake,
                              day: _day!,
                              bloc: _bloc,
                            ),
                          );
                          if (mounted) _bloc.add(LoadCalendarDayEvent(_day!));
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
