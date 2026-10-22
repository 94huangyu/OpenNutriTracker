import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';

import '../../test/helpers/full_backup_fixture.dart';
import '../../test/helpers/personal_food_fixture.dart';

// Run explicitly with flutter test; excluded from the routine test/ suite.
// RSS belongs to the macOS Flutter test worker, not an Android release app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final count in [1000, 5000]) {
    test(
      'synthetic full backup: $count intakes and 8 MiB attachment',
      () async {
        final fixture = await FullBackupFixture.open();
        addTearDown(fixture.close);
        final db = fixture.db;
        final random = Random(20261021);
        final photo = Uint8List.fromList(
          List.generate(8 * 1024 * 1024, (_) => random.nextInt(256)),
        );
        final file = File('${fixture.root.path}/meal_images/benchmark.webp');
        await file.writeAsBytes(photo, flush: true);
        final meal = MealDBO.fromJson({
          ...jsonDecode(jsonEncode(MealDBO.fromMealEntity(food()).toJson()))
              as Map<String, dynamic>,
          'localImagePath': 'meal_images/benchmark.webp',
        });
        await db.intakeBox.clear();
        await db.intakeBox.putAll({
          for (var i = 0; i < count; i++)
            i: IntakeDBO(
              id: 'benchmark-$i',
              unit: 'g',
              amount: 25,
              type: IntakeTypeDBO.lunch,
              meal: meal,
              dateTime: DateTime(2024, 1, 1).add(Duration(hours: i * 2)),
            ),
        });
        await db.intakeBox.flush();
        final service = fixture.service;
        final baselineRss = ProcessInfo.currentRss;
        final timer = Stopwatch()..start();
        final bytes = await service.export();
        final exportMs = timer.elapsedMilliseconds;
        final archive = ZipDecoder().decodeBytes(bytes);
        final inflatedBytes = archive.files.fold<int>(0, (n, f) => n + f.size);
        expect(bytes.length, lessThan(backupMaxZipBytes));
        expect(inflatedBytes, lessThan(backupMaxBytes));
        await db.intakeBox.clear();
        await file.delete();
        timer.reset();
        final preview = await service.preview(bytes);
        final previewMs = timer.elapsedMilliseconds;
        expect(preview.added, greaterThanOrEqualTo(count));
        expect(db.intakeBox.isEmpty, true);
        expect(await file.exists(), false);
        timer.reset();
        await service.restore(preview, RestoreConflictPolicy.keepLocal);
        final restoreMs = timer.elapsedMilliseconds;
        timer.stop();
        expect(db.intakeBox.length, count);
        expect(db.intakeBox.values.map((r) => r.id).toSet().length, count);
        expect(await file.readAsBytes(), orderedEquals(photo));
        expect(service.needsRecovery, false);
        expect(
          db.trackedDayBox.values.fold<double>(
            0,
            (n, d) => n + d.caloriesTracked,
          ),
          closeTo(count * 20, 0.001),
        );
        final repeat = await service.preview(bytes);
        expect(repeat.added, 0);
        await service.restore(repeat, RestoreConflictPolicy.keepLocal);
        expect(db.intakeBox.length, count);
        // Benchmark result is intentionally captured by the JSON test reporter.
        // ignore: avoid_print
        print(
          'ONT_BACKUP_BENCHMARK ${jsonEncode({'intakes': count, 'syntheticAttachmentBytes': photo.length, 'zipBytes': bytes.length, 'expandedBytes': inflatedBytes, 'exportMs': exportMs, 'previewMs': previewMs, 'restoreMs': restoreMs, 'workerRssBeforeBytes': baselineRss, 'workerRssAfterBytes': ProcessInfo.currentRss, 'workerLifetimePeakRssBytes': ProcessInfo.maxRss, 'restoredIntakes': db.intakeBox.length, 'repeatAdded': repeat.added, 'photoBytesMatch': true, 'platform': Platform.operatingSystem, 'scope': 'Flutter test worker; not device or release performance'})}',
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
}
