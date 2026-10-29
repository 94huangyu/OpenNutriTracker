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
  PageController? _pages;
  final _snapshots = <DateTime, Future<CalendarDayLoaded>>{};
  bool _refreshing = true;
  bool _paging = false;
  int _navigationGeneration = 0;
  int? _navigationTarget;
  static final _firstDay = DateTime(2000);
  static final _lastDay = DateTime(2100);
  Offset? _swipeOrigin;
  Offset? _swipePosition;
  double _dragStartPixels = 0;
  int _dragStartIndex = 0;
  bool _dragging = false;

  int _indexOf(DateTime day) => DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(_firstDay.year, _firstDay.month, _firstDay.day))
      .inDays;

  DateTime _dateAt(int index) => DateUtils.addDaysToDate(_firstDay, index);

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
      refreshIfSame: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _day != null) _refreshDay();
  }

  Future<CalendarDayLoaded> _snapshotFor(
    DateTime day,
  ) => _snapshots.putIfAbsent(day, () {
    final future = _bloc.loadDaySnapshot(day);
    // A prefetched neighbour can fail before it has a FutureBuilder listener.
    future.ignore();
    return future;
  });

  void _warmNeighbours() {
    final index = _indexOf(_day!);
    for (final offset in [-1, 1]) {
      final neighbour = index + offset;
      if (neighbour >= 0 && neighbour <= _indexOf(_lastDay)) {
        _snapshotFor(_dateAt(neighbour));
      }
    }
  }

  void _activatePage(int index) {
    final date = _dateAt(index);
    if (date == _day) return;
    setState(() {
      _day = date;
      _refreshing = true;
      _snapshots.removeWhere((day, _) => (_indexOf(day) - index).abs() > 2);
    });
    _bloc.add(LoadCalendarDayEvent(date));
    _warmNeighbours();
  }

  void _refreshDay() {
    setState(() {
      _snapshots.clear();
      _refreshing = true;
    });
    _bloc.add(LoadCalendarDayEvent(_day!));
    _warmNeighbours();
  }

  Future<void> _selectDay(DateTime day, {bool refreshIfSame = false}) async {
    final index = _indexOf(
      DateUtils.dateOnly(day),
    ).clamp(0, _indexOf(_lastDay));
    if (_pages == null) {
      _pages = PageController(initialPage: index, keepPage: false);
      _activatePage(index);
      return;
    }
    if (!_pages!.hasClients) return;
    final position = _pages!.page!;
    if ((position - index).abs() < .001) {
      setState(() {
        _paging = false;
        _navigationTarget = null;
      });
      if (refreshIfSame) _refreshDay();
      return;
    }
    final generation = ++_navigationGeneration;
    setState(() {
      _paging = true;
      _navigationTarget = index;
    });
    if (MediaQuery.disableAnimationsOf(context) ||
        (position - index).abs() > 1.1) {
      _pages!.jumpToPage(index);
    } else {
      await _pages!.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted || generation != _navigationGeneration) return;
    _activatePage(_pages!.page!.round());
    setState(() {
      _paging = false;
      _navigationTarget = null;
    });
  }

  void _shiftDay(int offset) {
    final index = (_navigationTarget ?? _indexOf(_day!)) + offset;
    if (index < 0 || index > _indexOf(_lastDay)) return;
    _selectDay(_dateAt(index));
  }

  void _startDaySwipe(DragStartDetails details) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final x = details.globalPosition.dx;
    final width = MediaQuery.sizeOf(context).width;
    _swipeOrigin = x <= insets.left || x >= width - insets.right
        ? null
        : details.globalPosition;
    _swipePosition = _swipeOrigin;
    _dragging = false;
    _dragStartPixels = _pages!.offset;
    _dragStartIndex = _pages!.page!.round();
  }

  void _updateDaySwipe(DragUpdateDetails details) {
    if (_swipeOrigin == null) return;
    _swipePosition = details.globalPosition;
    final delta = _swipePosition! - _swipeOrigin!;
    if (!_dragging) {
      if (delta.dx.abs() < delta.dy.abs() * 1.4) return;
      _dragging = true;
      ++_navigationGeneration;
      setState(() {
        _paging = true;
        _navigationTarget = null;
      });
    }
    final width = _pages!.position.viewportDimension;
    final min = ((_dragStartIndex - 1) * width).clamp(
      0.0,
      _pages!.position.maxScrollExtent,
    );
    final max = ((_dragStartIndex + 1) * width).clamp(
      0.0,
      _pages!.position.maxScrollExtent,
    );
    _pages!.jumpTo((_dragStartPixels - delta.dx).clamp(min, max));
  }

  void _finishDaySwipe(DragEndDetails details) {
    if (_swipeOrigin == null || !_dragging) {
      _swipeOrigin = _swipePosition = null;
      return;
    }
    final delta = _swipePosition! - _swipeOrigin!;
    _swipeOrigin = _swipePosition = null;
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final fling = velocity.abs() >= 500 && velocity * delta.dx > 0;
    final commit =
        delta.dx.abs() >= _pages!.position.viewportDimension * .28 ||
        (delta.dx.abs() >= 64 && fling);
    final offset = commit ? (delta.dx < 0 ? 1 : -1) : 0;
    _selectDay(
      _dateAt((_dragStartIndex + offset).clamp(0, _indexOf(_lastDay))),
    );
  }

  void _cancelDaySwipe() {
    _swipeOrigin = _swipePosition = null;
    if (_dragging) {
      _dragging = false;
      _selectDay(_dateAt(_dragStartIndex));
    }
  }

  Future<void> _add(AddMealType type, DateTime day) async {
    await Navigator.of(context).pushNamed(
      NavigationOptions.addMealRoute,
      arguments: AddMealScreenArguments(type, day),
    );
    if (mounted) _refreshDay();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return BlocListener<CalendarDayBloc, CalendarDayState>(
      bloc: _bloc,
      listener: (context, state) {
        if (state is CalendarDayLoaded && state.day == _day) {
          setState(() {
            _snapshots[_day!] = Future.value(state);
            _refreshing = false;
          });
        } else if (state is CalendarDayLoading) {
          setState(() => _refreshing = true);
        }
      },
      child: Scaffold(
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
                  if (mounted) _refreshDay();
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
                  if (mounted) _refreshDay();
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
                          onHorizontalDragUpdate: _updateDaySwipe,
                          onHorizontalDragEnd: _finishDaySwipe,
                          onHorizontalDragCancel: _cancelDaySwipe,
                          child: PageView.builder(
                            controller: _pages,
                            pageSnapping: false,
                            // Drive the native pager from our guarded gesture so edge
                            // navigation and predominantly vertical drags keep priority.
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _indexOf(_lastDay) + 1,
                            onPageChanged: _activatePage,
                            itemBuilder: (context, index) =>
                                _dayPage(_dateAt(index)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _dayPage(DateTime day) => FutureBuilder<CalendarDayLoaded>(
    key: ValueKey(day),
    future: _snapshotFor(day),
    builder: (context, snapshot) {
      final active = day == _day;
      final Widget content;
      if (snapshot.hasError && !snapshot.hasData) {
        content = Center(
          child: Semantics(
            identifier: active ? 'recording-day-retry' : null,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _snapshots.remove(day));
                if (active) _refreshDay();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(S.of(context).retryLabel),
            ),
          ),
        );
      } else if (!snapshot.hasData || snapshot.data!.day != day) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = Stack(
          fit: StackFit.expand,
          children: [
            _dayContent(snapshot.data!, day),
            if (active && _refreshing)
              const Positioned(
                top: 8,
                right: 16,
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      }
      return ExcludeSemantics(
        excluding: !active || _paging,
        child: IgnorePointer(
          ignoring: !active || _paging || (_refreshing && !snapshot.hasError),
          child: content,
        ),
      );
    },
  );

  Widget _dayContent(CalendarDayLoaded state, DateTime day) {
    final groups = [
      state.breakfastIntakeList,
      state.lunchIntakeList,
      state.dinnerIntakeList,
      state.snackIntakeList,
    ];
    return ListView(
      primary: false,
      key: PageStorageKey(day),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        RecordingNutrientSummary(
          items: groups.expand((items) => items).toList(),
        ),
        const SizedBox(height: 20),
        AppCard(
          shadowed: false,
          borderRadius: 18,
          child: Column(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _meal(context, AddMealType.values[i], groups[i], day),
              ],
            ],
          ),
        ),
      ],
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
    DateTime day,
  ) {
    final s = S.of(context);
    final total = items.fold<double>(0, (v, item) => v + item.totalKcal);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            identifier: day == _day ? 'recording-meal-${type.name}' : null,
            child: InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RecordingMealPage(day: day, type: type, bloc: _bloc),
                  ),
                );
                if (mounted) _refreshDay();
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
          identifier: day == _day ? 'recording-add-${type.name}' : null,
          child: IconButton(
            onPressed: () => _add(type, day),
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
