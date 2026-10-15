import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Optional local QA only. These system fonts are never bundled with the app.
Future<void> loadCaptureFonts() async {
  if (Platform.environment['ONT_CAPTURE_DIR'] == null) return;
  final font = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
  await (FontLoader('Nunito')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes()))))
      .load();
  final root = Platform.environment['ONT_PROJECT_ROOT']!;
  final icons = File(
    '$root/.tools/flutter-3.44.6/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes()))))
      .load();
}

Future<void> captureWidget(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final directory = Platform.environment['ONT_CAPTURE_DIR'];
  if (directory == null) return;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
