import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/data/dbo/profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';
import 'package:opennutritracker/features/settings/domain/backup/backup_dataset.dart';
import '../helpers/personal_food_fixture.dart';
import '../helpers/full_backup_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HiveDBProvider db;
  late FullBackupService service;
  late FullBackupFixture fixture;
  final day = DateTime(2026, 10, 20);

  setUp(() async {
    fixture = await FullBackupFixture.open();
    root = fixture.root;
    db = fixture.db;
    service = fixture.service;
  });
  tearDown(() async {
    await fixture.close();
  });

  Future<Map<String, dynamic>> data() async {
    final archive = ZipDecoder().decodeBytes(await service.export());
    return jsonDecode(
          utf8.decode(archive.findFile('data.json')!.content as List<int>),
        )
        as Map<String, dynamic>;
  }

  Uint8List changedZip(
    Uint8List bytes,
    void Function(Map<String, dynamic>) edit,
  ) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final payload =
        jsonDecode(
              utf8.decode(archive.findFile('data.json')!.content as List<int>),
            )
            as Map<String, dynamic>;
    edit(payload);
    final newData = utf8.encode(jsonEncode(payload));
    final manifest =
        jsonDecode(
              utf8.decode(
                archive.findFile('manifest.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    manifest['entries']['data.json'] = {
      'bytes': newData.length,
      'crc32': getCrc32(newData),
    };
    manifest['counts'] = {
      for (final b in payload['boxes'])
        '${b['name']}/${b['suffix']}': (b['rows'] as List).length,
    };
    final output = Archive();
    for (final f in archive.files) {
      final content = f.name == 'data.json'
          ? newData
          : f.name == 'manifest.json'
          ? utf8.encode(jsonEncode(manifest))
          : f.content as List<int>;
      output.addFile(ArchiveFile(f.name, content.length, content));
    }
    return Uint8List.fromList(ZipEncoder().encode(output));
  }

  test(
    'full manifest covers all stores; repeat restore is idempotent and preserves evidence/specification/settings/photos',
    () async {
      final bytes = await service.export();
      final preview = await service.preview(bytes);
      expect(preview.legacy, false);
      expect(preview.counts.length, backupDatasets.length);
      expect(preview.conflicts, 0);
      await service.restore(preview, RestoreConflictPolicy.keepLocal);
      final second = await service.preview(bytes);
      expect(second.added, 0);
      await service.restore(second, RestoreConflictPolicy.keepLocal);
      expect(db.intakeBox.length, 1);
      expect(db.personalFoodBox.values.single.reviewNote, '包装,"逐项"\n核对');
      expect(db.personalFoodBox.values.single.nutritionBasisQuantity, 15);
      expect(db.appConfigBox.values.single.usesKilojoules, true);
      expect(db.configBox.values.single.userCarbGoalPct, 0.45);
      expect(db.trackedDayBox.values.single.vitaminDGoal, 10);
      expect(await File('${root.path}/meal_images/test.webp').readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(
        await File(
          '${root.path}/meal_images/test.webp.credit.json',
        ).readAsString(),
        contains('作者'),
      );
      await Hive.close();
      db = HiveDBProvider();
      await db.initHiveDB(Uint8List.fromList(List.generate(32, (i) => i)));
      await db.openProfileBoxes('p', '');
      expect(db.intakeBox.values.single.amount, 25);
      expect(db.personalFoodBox.values.single.reviewSource, 'package');
    },
  );

  test(
    'restore new profile cannot overwrite unrelated local empty-suffix profile',
    () async {
      await db.profileBox.put(
        'other',
        ProfileDBO(
          id: 'other',
          name: '第二份',
          createdAt: day,
          boxSuffix: 'second',
        ),
      );
      final otherBox = await db.openScopedBox<WaterIntakeDBO>(
        HiveDBProvider.waterIntakeBoxName,
        'second',
      );
      await otherBox.put(
        'water',
        WaterIntakeDBO(id: 'water', dateTime: day, amountMl: 444),
      );
      await otherBox.close();
      final bytes = await service.export();
      await db.profileBox.clear();
      await db.profileBox.put(
        'local',
        ProfileDBO(id: 'local', name: '本机', createdAt: day, boxSuffix: ''),
      );
      await db.openProfileBoxes('local', '');
      final preview = await service.preview(bytes);
      await service.restore(preview, RestoreConflictPolicy.useBackup);
      expect(db.profileBox.length, 3);
      expect(db.profileBox.get('local')!.boxSuffix, '');
      final imported = db.profileBox.get('p')!;
      expect(imported.boxSuffix, isNot(''));
      final intake = await db.openScopedBox<IntakeDBO>(
        HiveDBProvider.intakeBoxName,
        imported.boxSuffix,
      );
      expect(intake.values.single.id, 'intake');
      await intake.close();
      final p2 = db.profileBox.get('other')!;
      final water = await db.openScopedBox<WaterIntakeDBO>(
        HiveDBProvider.waterIntakeBoxName,
        p2.boxSuffix,
      );
      expect(water.values.single.amountMl, 444);
      await water.close();
      expect((await service.preview(bytes)).added, 0);
    },
  );

  for (final policy in RestoreConflictPolicy.values) {
    test(
      'conflict policy $policy and UUID/key collisions recalculate merged totals',
      () async {
        final bytes = await service.export();
        db.intakeBox.values.single.amount = 50;
        await db.intakeBox.values.single.save();
        await db.intakeBox.put(
          8,
          IntakeDBO(
            id: 'local-only',
            unit: 'g',
            amount: 10,
            type: IntakeTypeDBO.lunch,
            meal: MealDBO.fromMealEntity(food()),
            dateTime: day,
          ),
        );
        final preview = await service.preview(bytes);
        expect(preview.conflicts, 1);
        await service.restore(preview, policy);
        expect(db.intakeBox.length, 2);
        expect(
          db.intakeBox.values.firstWhere((i) => i.id == 'intake').amount,
          policy == RestoreConflictPolicy.keepLocal ? 50 : 25,
        );
        expect(
          db.trackedDayBox.values.single.caloriesTracked,
          policy == RestoreConflictPolicy.keepLocal ? 48 : 28,
        );
        expect(db.trackedDayBox.values.single.calorieGoal, 1800);
      },
    );
  }

  test(
    'preview is read-only, cancellation leaves data, stale preview cannot commit',
    () async {
      final before = await data();
      final preview = await service.preview(await service.export());
      expect(await data(), before);
      await db.waterIntakeBox.clear();
      await expectLater(
        service.restore(preview, RestoreConflictPolicy.useBackup),
        throwsStateError,
      );
      expect(db.waterIntakeBox.isEmpty, true);
    },
  );

  test('later box or image failure rolls back all previous writes', () async {
    final bytes = await service.export();
    await db.waterIntakeBox.clear();
    final before = await data();
    for (final step in [
      HiveDBProvider.waterIntakeBoxName,
      'meal_images/test.webp',
    ]) {
      final failing = FullBackupService(
        db,
        root,
        afterWrite: (name) async {
          if (name == step) {
            throw const FileSystemException('Injected disk failure');
          }
        },
      );
      final preview = await failing.preview(bytes);
      await expectLater(
        failing.restore(preview, RestoreConflictPolicy.useBackup),
        throwsA(isA<FileSystemException>()),
      );
      expect(await data(), before);
      expect(
        (await db.openScopedBox<dynamic>('RestoreJournal', '')).isEmpty,
        true,
      );
    }
  });

  test(
    'encrypted pending journal replays after close/reopen before profile bootstrap',
    () async {
      final before = await data();
      final journal = await db.openScopedBox<dynamic>('RestoreJournal', '');
      await journal.put('before', {
        'boxes': before['boxes'],
        'images': {
          'meal_images/test.webp': base64Encode([1, 2, 3]),
        },
      });
      await journal.flush();
      await db.intakeBox.clear();
      await File('${root.path}/meal_images/test.webp').writeAsBytes([9]);
      await Hive.close();
      db = HiveDBProvider();
      await db.initHiveDB(Uint8List.fromList(List.generate(32, (i) => i)));
      service = FullBackupService(db, root);
      await service.recoverPendingRestore();
      await db.openProfileBoxes('p', '');
      expect(await data(), before);
      expect(await File('${root.path}/meal_images/test.webp').readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );

  test(
    'invalid final dataset/duplicates/incomplete scope rejected before writes',
    () async {
      final bytes = await service.export();
      final before = await data();
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (p) => p['boxes'].last['rows'] = [
          {'key': 'bad', 'value': {}},
        ],
        (p) => p['boxes'].removeLast(),
        (p) => p['boxes'][7]['rows'].add(p['boxes'][7]['rows'].first),
        (p) => p['boxes'][0]['rows'][0]['value']['boxSuffix'] = '../../outside',
      ]) {
        await expectLater(
          service.preview(changedZip(bytes, mutate)),
          throwsA(anything),
        );
        expect(await data(), before);
      }
    },
  );

  test(
    'old JSON ZIP required/optional datasets join preview, repair and idempotent restore',
    () async {
      final original = await data();
      final archive = Archive();
      for (final e in {
        'user_activity.json': HiveDBProvider.userActivityBoxName,
        'user_intake.json': HiveDBProvider.intakeBoxName,
        'user_tracked_day.json': HiveDBProvider.trackedDayBoxName,
      }.entries) {
        final b = (original['boxes'] as List).firstWhere(
          (b) => b['name'] == e.value,
        );
        final content = utf8.encode(
          jsonEncode([for (final r in b['rows']) r['value']]),
        );
        archive.addFile(ArchiveFile(e.key, content.length, content));
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final p = await service.preview(bytes);
      expect(p.legacy, true);
      expect(p.counts.length, 3);
      await service.restore(p, RestoreConflictPolicy.keepLocal);
      await service.restore(
        await service.preview(bytes),
        RestoreConflictPolicy.keepLocal,
      );
      expect(db.intakeBox.length, 1);
      archive.removeFile(archive.findFile('user_tracked_day.json')!);
      await expectLater(
        service.preview(Uint8List.fromList(ZipEncoder().encode(archive))),
        throwsFormatException,
      );
    },
  );
  test(
    'all fourteen populated stores and all photo types restore from empty stores',
    () async {
      final original = await data();
      final bytes = await service.export();
      for (final d in backupDatasets.where(
        (d) => d.name != HiveDBProvider.profileBoxName,
      )) {
        await d.replace(db, '', []);
      }
      for (final path in ['meal_images', 'recipe_images', 'profile_images']) {
        await Directory('${root.path}/$path').delete(recursive: true);
      }
      await service.restore(
        await service.preview(bytes),
        RestoreConflictPolicy.useBackup,
      );
      expect(await data(), original);
      for (final path in [
        'meal_images/test.webp',
        'recipe_images/recipe.webp',
        'profile_images/avatar.webp',
      ]) {
        expect(await File('${root.path}/$path').readAsBytes(), [1, 2, 3]);
      }
      expect(db.userBox.values.single.caloriesTaperEnabled, true);
      expect(
        db
            .recipeBox
            .values
            .single
            .ingredients
            .single
            .snapshotMeal
            .nutriments
            .vitaminA100,
        isNotNull,
      );
    },
  );

  test(
    'legacy CSV handles escaped personal evidence and repeated imports',
    () async {
      final archive = Archive();
      final files = {
        'user_activity.csv': CsvDataExporter.userActivitiesToCsv(
          db.userActivityBox.values.toList(),
        ),
        'user_intake.csv': CsvDataExporter.intakesToCsv(
          db.intakeBox.values.toList(),
        ),
        'user_tracked_day.csv': CsvDataExporter.trackedDaysToCsv(
          db.trackedDayBox.values.toList(),
        ),
        'personal_foods.csv': CsvDataExporter.mealsToCsv(
          db.personalFoodBox.values.toList(),
        ),
      };
      for (final e in files.entries) {
        final content = utf8.encode(e.value);
        archive.addFile(ArchiveFile(e.key, content.length, content));
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      await db.intakeBox.clear();
      await db.personalFoodBox.clear();
      final preview = await service.preview(bytes);
      expect(preview.legacy, true);
      await service.restore(preview, RestoreConflictPolicy.useBackup);
      await service.restore(
        await service.preview(bytes),
        RestoreConflictPolicy.useBackup,
      );
      expect(db.intakeBox.length, 1);
      expect(db.personalFoodBox.values.single.reviewNote, '包装,"逐项"\n核对');
    },
  );

  test(
    'corruption, unknown versions, traversal and symlinks leave data untouched',
    () async {
      final before = await data();
      final bytes = await service.export();
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.findFile('manifest.json')!.content as List<int>,
                ),
              )
              as Map;
      for (final version in [0, 2, 1.0, '1']) {
        final a = Archive();
        for (final f in archive.files) {
          final content = f.name == 'manifest.json'
              ? utf8.encode(jsonEncode({...manifest, 'version': version}))
              : f.content as List<int>;
          a.addFile(ArchiveFile(f.name, content.length, content));
        }
        await expectLater(
          service.preview(Uint8List.fromList(ZipEncoder().encode(a))),
          throwsFormatException,
        );
      }
      for (final name in [
        '../outside',
        'meal_images/../../outside',
        r'meal_images\outside',
      ]) {
        final a = Archive();
        final content = [1, 2, 3];
        a.addFile(ArchiveFile(name, content.length, content));
        await expectLater(
          service.preview(Uint8List.fromList(ZipEncoder().encode(a))),
          throwsA(anything),
        );
      }
      final damaged = Uint8List.fromList(bytes);
      damaged[40] ^= 0xff;
      await expectLater(service.preview(damaged), throwsA(anything));
      expect(await data(), before);
      // The destination symlink is rejected, never followed into an external file.
      final preview = await service.preview(bytes);
      final image = File('${root.path}/meal_images/test.webp');
      await image.delete();
      final outside = File('${root.path}/outside')..writeAsBytesSync([8, 8]);
      await Link(image.path).create(outside.path);
      await expectLater(
        service.restore(preview, RestoreConflictPolicy.useBackup),
        throwsA(anything),
      );
      expect(await outside.readAsBytes(), [8, 8]);
      await Link(image.path).delete();
      await image.writeAsBytes([1, 2, 3]);
    },
  );

  test(
    'ZIP directory inflated-size limit rejects before decoding payload',
    () async {
      final archive = Archive()
        ..addFile(ArchiveFile('tiny.json', 2, utf8.encode('[]')));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      // Central directory uncompressed-size slot. No large allocation is needed
      // to test the declared-size guard.
      for (var i = 0; i < bytes.length - 28; i++) {
        if (bytes[i] == 0x50 &&
            bytes[i + 1] == 0x4b &&
            bytes[i + 2] == 1 &&
            bytes[i + 3] == 2) {
          ByteData.sublistView(
            bytes,
          ).setUint32(i + 24, backupMaxBytes + 1, Endian.little);
          break;
        }
      }
      await expectLater(service.preview(bytes), throwsFormatException);
    },
  );
  test(
    'rollback failure retains encrypted journal and blocks further restore until retry',
    () async {
      final bytes = await service.export();
      await db.waterIntakeBox.clear();
      final before = await data();
      final path = '${root.path}/meal_images/test.webp';
      var injected = false;
      final failing = FullBackupService(
        db,
        root,
        afterWrite: (name) async {
          if (!injected && name == HiveDBProvider.waterIntakeBoxName) {
            injected = true;
            await File(path).delete();
            await Directory(path).create();
            throw const FileSystemException(
              'Injected write and rollback failure',
            );
          }
        },
      );
      final preview = await failing.preview(bytes);
      await expectLater(
        failing.restore(preview, RestoreConflictPolicy.useBackup),
        throwsA(isA<FileSystemException>()),
      );
      expect(failing.needsRecovery, true);
      final journal = await db.openScopedBox<dynamic>('RestoreJournal', '');
      expect(journal.isEmpty, false);
      await expectLater(failing.export(), throwsStateError);
      await Directory(path).delete();
      final recovering = FullBackupService(db, root);
      await recovering.recoverPendingRestore();
      expect(journal.isEmpty, true);
      expect(await data(), before);
      expect(await File(path).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'restoring settings cannot import privacy consent from the backup',
    () async {
      final bytes = changedZip(await service.export(), (p) {
        for (final b in p['boxes']) {
          if (b['name'] == HiveDBProvider.appConfigBoxName ||
              b['name'] == HiveDBProvider.configBoxName) {
            b['rows'].first['value']['hasAcceptedSendAnonymousData'] = true;
            b['rows'].first['value']['hasAcceptedPolicy'] = true;
            b['rows'].first['value']['usesKilojoules'] = false;
          }
        }
      });
      await service.restore(
        await service.preview(bytes),
        RestoreConflictPolicy.useBackup,
      );
      expect(db.appConfigBox.values.single.hasAcceptedSendAnonymousData, false);
      expect(db.appConfigBox.values.single.hasAcceptedPolicy, false);
      expect(db.appConfigBox.values.single.usesKilojoules, false);
    },
  );
}
