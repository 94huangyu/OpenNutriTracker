// Explicit device target, never used by lib/main.dart or routine test discovery.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/backup/backup_dataset.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';

import '../../test/helpers/full_backup_fixture.dart';
import 'm5_performance_fixture.dart';

const validationPackage =
    'com.opennutritracker.ont.opennutritracker.validation';

void requireValidationPackage(String package) {
  if (package != validationPackage) {
    throw StateError(
      'Device probe refuses non-validation application identity',
    );
  }
}

Map<String, Object> portableSnapshot(List<int> zip) {
  final archive = ZipDecoder().decodeBytes(zip);
  return {
    for (final file in archive.files)
      if (file.name != 'manifest.json')
        file.name: file.name == 'data.json'
            ? jsonDecode(utf8.decode(file.content as List<int>)) as Object
            : base64Encode(file.content as List<int>),
  };
}

/// Import allocates fresh storage scopes; compare their owning profile IDs.
/// All record values and attachment bytes remain part of the comparison.
Map<String, Object> canonicalProfileScopes(Map<String, Object> snapshot) {
  final copy = (jsonDecode(jsonEncode(snapshot)) as Map).cast<String, Object>();
  final data = copy['data.json'] as Map;
  final boxes = data['boxes'] as List;
  final profiles =
      (boxes.singleWhere(
            (b) => b['name'] == HiveDBProvider.profileBoxName,
          )['rows']
          as List);
  final owners = <String, String>{};
  for (final row in profiles) {
    final profile = row['value'] as Map;
    final scope = profile['boxSuffix'] as String;
    check(!owners.containsKey(scope), 'Duplicate profile storage scope');
    owners[scope] = profile['id'] as String;
    profile['boxSuffix'] = 'profile:${profile['id']}';
  }
  for (final box in boxes) {
    if (datasetNamed(box['name'] as String).global) continue;
    final owner = owners[box['suffix']];
    check(owner != null, 'Unregistered profile storage scope');
    box['suffix'] = 'profile:$owner';
  }
  return copy;
}

void check(bool condition, String message) {
  // Runtime checks stay active in profile/release builds too.
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guard BEFORE obtaining paths, opening Hive, or creating synthetic records.
  requireValidationPackage((await PackageInfo.fromPlatform()).packageName);
  final support = await getApplicationSupportDirectory();
  final control = Directory('${support.path}/m5-validation');
  await control.create(recursive: true);
  final status = ValueNotifier<String>('准备隔离检查');
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('M5 隔离恢复验证')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    ),
  );

  Future<void> report(Map<String, Object?> result) async {
    final text = jsonEncode(result);
    final temporary = File('${control.path}/status.tmp');
    await temporary.writeAsString(text, flush: true);
    await temporary.rename('${control.path}/status.json');
    status.value = text;
    debugPrint('ONT_M5_DEVICE_RESULT $text');
  }

  void guardRoot(Directory root) {
    final path = root.resolveSymbolicLinksSync();
    final temporary = Directory.systemTemp.resolveSymbolicLinksSync();
    final sandbox = support.parent.resolveSymbolicLinksSync();
    check(
      temporary.startsWith('$sandbox/') &&
          Directory(path).parent.path == temporary &&
          RegExp(r'^ont-m4-fixture-[a-zA-Z0-9]+$').hasMatch(
            Directory(path).uri.pathSegments.where((s) => s.isNotEmpty).last,
          ),
      'Refuses a non-fixture root: $path; temporary=$temporary; sandbox=$sandbox',
    );
    check(!FileSystemEntity.isLinkSync(path), 'Refuses a linked root');
  }

  final commandFile = File('${support.path}/m5-command.json');
  final command = await commandFile.exists()
      ? jsonDecode(await commandFile.readAsString()) as Map<String, dynamic>
      : <String, dynamic>{'mode': 'roundtrip'};
  final mode = command['mode'];
  FullBackupFixture? fixture;
  try {
    if (mode == 'seed_performance') {
      final result = await seedPerformanceFixture(validationPackage);
      await report({'mode': mode, 'passed': true, ...result});
      return;
    }
    if (mode == 'recover') {
      final context =
          jsonDecode(await File('${control.path}/restart.json').readAsString())
              as Map<String, dynamic>;
      final root = Directory(context['root'] as String);
      guardRoot(root);
      fixture = await FullBackupFixture.reopen(root);
      await fixture.service.recoverPendingRestore();
      final journal = await fixture.db.openScopedBox<dynamic>(
        'RestoreJournal',
        '',
      );
      check(journal.isEmpty, 'Recovery journal not cleared');
      check(
        const DeepCollectionEquality().equals(
          portableSnapshot(await fixture.service.export()),
          context['before'],
        ),
        'Restart recovery differs from pre-restore data/images',
      );
      await fixture.close();
      fixture = null;
      await report({
        'mode': mode,
        'passed': true,
        'journalCleared': true,
        'allDataAndImagesRolledBack': true,
        'fixtureRemoved': true,
      });
      return;
    }
    check(
      ['roundtrip', 'write_failure', 'interrupt'].contains(mode),
      'Unknown mode',
    );
    fixture = await FullBackupFixture.open();
    guardRoot(fixture.root);
    // Generate and import real decodable images without accessing any gallery.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, 32),
      Paint()..color = Colors.green,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = Colors.orange,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    final png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    final source = File('${fixture.root.path}/probe.png');
    await source.writeAsBytes(png);
    for (final pair in [
      (UserImageKind.meal, 'test'),
      (UserImageKind.recipe, 'recipe'),
      (UserImageKind.profile, 'avatar'),
    ]) {
      final path = await UserImageStorage.importFrom(
        kind: pair.$1,
        ownerId: pair.$2,
        sourcePath: source.path,
      );
      final codec = await ui.instantiateImageCodec(
        await File('${fixture.root.path}/$path').readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      check(
        frame.image.width > 0 && frame.image.height > 0,
        'Image decode failed',
      );
      frame.image.dispose();
      codec.dispose();
    }
    await source.delete();
    await File(
      '${fixture.root.path}/meal_images/test.webp.credit.json',
    ).writeAsString('{"name":"作者"}');
    final service = fixture.service;
    final bytes = await service.export();
    final original = portableSnapshot(bytes);
    if (mode == 'roundtrip') {
      for (final dataset in backupDatasets) {
        final box = await dataset.open(fixture.db, '');
        await box.clear();
        await box.flush();
      }
      for (final kind in UserImageKind.values) {
        final dir = Directory('${fixture.root.path}/${kind.subdir}');
        if (await dir.exists()) await dir.delete(recursive: true);
      }
      final timer = Stopwatch()..start();
      final preview = await service.preview(bytes);
      final previewMs = timer.elapsedMilliseconds;
      check(
        preview.counts.length == 14 && preview.added > 0,
        'Incomplete preview',
      );
      check(fixture.db.intakeBox.isEmpty, 'Preview wrote records');
      timer.reset();
      await service.restore(preview, RestoreConflictPolicy.useBackup);
      final restoreMs = timer.elapsedMilliseconds;
      check(
        const DeepCollectionEquality().equals(
          canonicalProfileScopes(portableSnapshot(await service.export())),
          canonicalProfileScopes(original),
        ),
        'Restore differs',
      );
      final repeat = await service.preview(bytes);
      check(repeat.added == 0, 'Repeat restore would duplicate records');
      await service.restore(repeat, RestoreConflictPolicy.useBackup);
      check(
        const DeepCollectionEquality().equals(
          canonicalProfileScopes(portableSnapshot(await service.export())),
          canonicalProfileScopes(original),
        ),
        'Repeat differs',
      );
      await fixture.close();
      fixture = null;
      await report({
        'mode': mode,
        'passed': true,
        'datasets': 14,
        'decodedImages': 3,
        'repeatAdded': 0,
        'previewMs': previewMs,
        'restoreMs': restoreMs,
        'fixtureRemoved': true,
      });
    } else {
      await fixture.db.waterIntakeBox.clear();
      final before = portableSnapshot(await service.export());
      final failing = FullBackupService(
        fixture.db,
        fixture.root,
        afterWrite: (step) async {
          if (step != HiveDBProvider.waterIntakeBoxName) return;
          if (mode == 'write_failure') {
            throw const FileSystemException(
              'Synthetic ENOSPC',
              '',
              OSError('No space left', 28),
            );
          }
          await File('${control.path}/restart.json').writeAsString(
            jsonEncode({'root': fixture!.root.path, 'before': before}),
            flush: true,
          );
          await report({
            'mode': mode,
            'phase': 'waiting_for_host_force_stop',
            'journalFlushed': true,
            'partiallyWrittenDataset': step,
          });
          await Completer<void>().future;
        },
      );
      final preview = await failing.preview(bytes);
      try {
        await failing.restore(preview, RestoreConflictPolicy.useBackup);
        throw StateError('Expected injected write failure');
      } on FileSystemException {
        check(mode == 'write_failure', 'Unexpected IO failure');
        check(!failing.needsRecovery, 'Rollback did not complete');
        check(
          const DeepCollectionEquality().equals(
            portableSnapshot(await service.export()),
            before,
          ),
          'Rollback differs',
        );
        await fixture.close();
        fixture = null;
        await report({
          'mode': mode,
          'passed': true,
          'allDataAndImagesRolledBack': true,
          'syntheticError': 'ENOSPC; device storage was not filled',
          'fixtureRemoved': true,
        });
      }
    }
  } catch (error, stack) {
    await report({
      'mode': mode,
      'passed': false,
      'error': '$error',
      'stack': '$stack',
    });
    if (fixture != null) await fixture.close();
  }
}
