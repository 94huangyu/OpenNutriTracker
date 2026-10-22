import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/splash_screen.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';

Future<Uint8List> pixels(
  WidgetTester tester,
  GlobalKey key, {
  String? capture,
}) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final raw = await image.toByteData();
      final directory = Platform.environment['ONT_SPLASH_CAPTURE_DIR'];
      if (directory != null && capture != null) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$directory/$capture.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      }
      return raw!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

Widget app(GlobalKey key) => MaterialApp(
  home: RepaintBoundary(
    key: key,
    child: const SplashScreen(userInitialized: false),
  ),
  routes: {
    NavigationOptions.mainRoute: (_) => const Scaffold(body: Text('diary')),
  },
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: dots settle and diary opens at 800ms', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final key = GlobalKey();
      await tester.pumpWidget(app(key));
      final frames = <int, Uint8List>{};
      for (var time = 0; time <= 750; time += 50) {
        if (time > 0) await tester.pump(const Duration(milliseconds: 50));
        frames[time] = await pixels(
          tester,
          key,
          capture: '${brightness.name}-$time',
        );
        expect(find.text('diary'), findsNothing);
      }
      expect(frames[150], isNot(orderedEquals(frames[0]!)));
      expect(frames[300], orderedEquals(frames[0]!));
      expect(frames[500], isNot(orderedEquals(frames[0]!)));
      expect(frames[650], orderedEquals(frames[0]!));
      expect(frames[750], orderedEquals(frames[0]!));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.text('diary'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disabled animation stays still and enters diary after 600ms', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final key = GlobalKey();
    await tester.pumpWidget(app(key));
    final first = await pixels(tester, key);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await pixels(tester, key), orderedEquals(first));
    expect(find.text('diary'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('diary'), findsOneWidget);
  });

  for (final disabled in [false, true]) {
    testWidgets('disposing splash cancels pending work: disabled=$disabled', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: disabled);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(app(GlobalKey()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('diary'), findsNothing);
    });
  }
}
