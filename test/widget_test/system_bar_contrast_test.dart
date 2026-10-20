import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/main.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/utils/locale_provider.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';

void main() {
  testWidgets(
    'app fallback restores readable system bars after routes and theme changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      final theme = ThemeModeProvider(appTheme: AppThemeEntity.light);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider(
              create: (_) => LocaleProvider(locale: const Locale('zh')),
            ),
          ],
          child: const OpenNutriTrackerApp(userInitialized: false),
        ),
      );
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      // Replace the animated splash before it navigates; no user database is needed.
      navigator.pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) =>
              Scaffold(appBar: AppBar(title: const Text('首页'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const SafeArea(child: Scaffold(body: Text('safe-area-route'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      theme.updateTheme(AppThemeEntity.dark);
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      theme.updateTheme(AppThemeEntity.light);
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      theme.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
