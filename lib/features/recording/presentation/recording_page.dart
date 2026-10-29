import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/recording/presentation/recording_settings.dart';
import 'package:opennutritracker/features/recording/presentation/recording_meal_page.dart';
import 'package:opennutritracker/features/recording/presentation/widgets/recording_nutrient_summary.dart';
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
  static final _firstDay = DateTime(2000);
  static final _lastDay = DateTime(2100);
  Offset? _swipeOrigin;
  Offset? _swipePosition;

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
    final date = DateUtils.dateOnly(day);
    setState(
      () => _day = date.isBefore(_firstDay)
          ? _firstDay
          : date.isAfter(_lastDay)
          ? _lastDay
          : date,
    );
    _bloc.add(LoadCalendarDayEvent(_day!));
  }

  void _shiftDay(int offset) {
    final date = DateUtils.addDaysToDate(_day!, offset);
    if (date.isBefore(_firstDay) || date.isAfter(_lastDay)) return;
    _selectDay(date);
  }

  void _startDaySwipe(DragStartDetails details) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final x = details.globalPosition.dx;
    final width = MediaQuery.sizeOf(context).width;
    _swipeOrigin = x <= insets.left || x >= width - insets.right
        ? null
        : details.globalPosition;
    _swipePosition = _swipeOrigin;
  }

  void _finishDaySwipe(DragEndDetails _) {
    final delta = _swipeOrigin == null || _swipePosition == null
        ? Offset.zero
        : _swipePosition! - _swipeOrigin!;
    _swipeOrigin = _swipePosition = null;
    if (delta.dx.abs() < 64 || delta.dx.abs() < delta.dy.abs() * 1.4) return;
    _shiftDay(delta.dx < 0 ? 1 : -1);
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(s.recordingTitle),
        actions: [
          Semantics(
            identifier: 'recording-food-library',
            child: IconButton(
              tooltip: s.recipesLabel,
              icon: const Icon(Icons.kitchen_outlined),
              onPressed: () async {
                await Navigator.of(
                  context,
                ).pushNamed(NavigationOptions.recipesRoute);
                if (mounted) _bloc.add(LoadCalendarDayEvent(_day!));
              },
            ),
          ),
          Semantics(
            identifier: 'recording-settings',
            child: IconButton(
              tooltip: s.settingsLabel,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecordingSettings(),
                  ),
                );
                if (mounted) _bloc.add(LoadCalendarDayEvent(_day!));
              },
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
                    child: Semantics(
                      identifier: 'recording-day-content',
                      container: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.down,
                        onHorizontalDragStart: _startDaySwipe,
                        onHorizontalDragUpdate: (details) =>
                            _swipePosition = details.globalPosition,
                        onHorizontalDragEnd: _finishDaySwipe,
                        onHorizontalDragCancel: () =>
                            _swipeOrigin = _swipePosition = null,
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
                            final all = groups
                                .expand((items) => items)
                                .toList();
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                RecordingNutrientSummary(items: all),
                                const SizedBox(height: 20),
                                AppCard(
                                  shadowed: false,
                                  borderRadius: 18,
                                  child: Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < groups.length;
                                        i++
                                      ) ...[
                                        if (i > 0)
                                          const Divider(
                                            height: 1,
                                            indent: 16,
                                            endIndent: 16,
                                          ),
                                        _meal(
                                          context,
                                          AddMealType.values[i],
                                          groups[i],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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
            onPressed: _day!.isAfter(_firstDay) ? () => _shiftDay(-1) : null,
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
                  firstDate: _firstDay,
                  lastDate: _lastDay,
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
            onPressed: _day!.isBefore(_lastDay) ? () => _shiftDay(1) : null,
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

  Widget _meal(
    BuildContext context,
    AddMealType type,
    List<IntakeEntity> items,
  ) {
    final s = S.of(context);
    final total = items.fold<double>(0, (v, item) => v + item.totalKcal);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            identifier: 'recording-meal-${type.name}',
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RecordingMealPage(day: _day!, type: type, bloc: _bloc),
                  ),
                );
                if (mounted) _bloc.add(LoadCalendarDayEvent(_day!));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 4, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: type.getTypeName(context),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        children: [
                          TextSpan(
                            text:
                                '   ${EnergyDisplay.formatRoundedWithUnit(context, total)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      items.isEmpty
                          ? s.recordingNotRecorded
                          : items.map((i) => i.meal.name ?? '').join('、'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Semantics(
          identifier: 'recording-add-${type.name}',
          child: IconButton(
            onPressed: () => _add(type),
            tooltip: s.addLabel,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .12),
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
