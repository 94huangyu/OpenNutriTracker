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
    'app restores current system bars after routes, theme changes and keyboard',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
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
      List<String?> iconRequests() => calls
          .where(
            (call) => call.method == 'SystemChrome.setSystemUIOverlayStyle',
          )
          .map(
            (call) =>
                (call.arguments as Map)['statusBarIconBrightness'] as String?,
          )
          .toList();
      calls.clear();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 900));
      expect(iconRequests(), isEmpty);
      // Reopening cancels the pending refresh while the IME owns the chrome.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 400));
      expect(iconRequests(), isEmpty);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(iconRequests(), ['Brightness.light', 'Brightness.dark']);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      // Use the route's current style, not a light theme captured at dismissal.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      theme.updateTheme(AppThemeEntity.dark);
      await tester.pumpAndSettle();
      calls.clear();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(iconRequests(), isEmpty);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      theme.updateTheme(AppThemeEntity.light);
      await tester.pumpAndSettle();
      calls.clear();
      // No platform operation after the app is disposed.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1200));
      expect(iconRequests(), isEmpty);
      await tester.pumpAndSettle();
      theme.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
