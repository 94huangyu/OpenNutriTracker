import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/recording/presentation/recording_page.dart';
import 'package:opennutritracker/features/recording/presentation/recording_settings.dart';
import 'package:opennutritracker/features/recording/presentation/recording_trends_page.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Recording-only tabs. No tab requires or loads a body profile.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  final _pages = <int, Widget>{0: const RecordingPage()};
  Widget _page(int index) => switch (index) {
    0 => const RecordingPage(),
    1 => const RecipesPage(),
    2 => const RecordingTrendsPage(),
    _ => RecordingSettings(onDataChanged: _dataChanged),
  };
  void _dataChanged() {
    setState(() {
      // Restore/profile changes invalidate profile-scoped screens. A new key
      // prevents the diary's previous profile/date from surviving the change.
      for (final index in [0, 1, 2]) {
        _pages.remove(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    _pages.putIfAbsent(
      _selected,
      () => KeyedSubtree(key: UniqueKey(), child: _page(_selected)),
    );
    return Scaffold(
      // The diary has no inline input; late IME metrics must not shrink it.
      resizeToAvoidBottomInset: _selected != 0,
      body: IndexedStack(
        index: _selected,
        children: [
          for (var i = 0; i < 4; i++) _pages[i] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Semantics(
        identifier: 'recording-navigation',
        child: NavigationBar(
          height: MediaQuery.textScalerOf(context).scale(64).clamp(80, 120),
          selectedIndex: _selected,
          onDestinationSelected: (index) => setState(() {
            if (index == 0 && _selected != 0 && _pages.containsKey(0)) {
              locator<CalendarDayBloc>().add(const RefreshCalendarDayEvent());
            }
            if (index != _selected && index != 0) _pages.remove(index);
            _selected = index;
          }),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              label: s.diaryLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.kitchen_outlined),
              label: s.m4Library,
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              label: s.trendsLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: s.m4My,
            ),
          ],
        ),
      ),
    );
  }
}
