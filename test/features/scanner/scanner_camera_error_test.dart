import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/features/scanner/presentation/widgets/scanner_camera_error.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

void main() {
  setUpAll(loadCaptureFonts);
  for (final denied in [false, true]) {
    testWidgets(
      'camera failure is localized and retryable; permission denied=$denied',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final capture = GlobalKey();
        var attempts = 0;
        final retry = Completer<void>();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(AppPalette.light),
              locale: const Locale('zh'),
              supportedLocales: S.supportedLocales,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('扫描条形码')),
                body: ScannerCameraError(
                  error: MobileScannerException(
                    errorCode: denied
                        ? MobileScannerErrorCode.permissionDenied
                        : MobileScannerErrorCode.genericError,
                  ),
                  onRetry: () {
                    attempts++;
                    return retry.future;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(denied ? '未获得相机权限' : '相机暂时无法使用'),
          findsOneWidget,
        );
        expect(find.textContaining('Camera permission denied'), findsNothing);
        final button = find.byType(FilledButton);
        await tester.ensureVisible(button);
        await captureWidget(tester, capture, 'scanner-camera-error-$denied');
        await tester.tap(button);
        await tester.pump();
        expect(attempts, 1);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        retry.completeError(StateError('simulated permission denial'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
