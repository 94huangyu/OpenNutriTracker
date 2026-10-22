import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/dbo/profile_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/backup/backup_dataset.dart';
import 'package:opennutritracker/features/settings/domain/backup/legacy_backup_reader.dart';

// The compressed input, inflated total and entry count are bounded before
// decompression. This codec is intentionally for local mobile-sized backups.
const backupMaxBytes = 64 * 1024 * 1024;
const backupMaxZipBytes = 32 * 1024 * 1024;
const backupMaxEntries = 10000;

enum RestoreConflictPolicy { keepLocal, useBackup }

class RestorePreview {
  final bool legacy;
  final Map<String, int> counts;
  final int added;
  final int conflicts;
  final int unchanged;
  final int imageConflicts;
  final int imageFiles;
  final Map<String, dynamic> _before;
  final Map<String, dynamic> _afterKeep;
  final Map<String, dynamic> _afterBackup;
  RestorePreview._(
    this.legacy,
    this.counts,
    this.added,
    this.conflicts,
    this.unchanged,
    this.imageConflicts,
    this.imageFiles,
    this._before,
    this._afterKeep,
    this._afterBackup,
  );
}

/// Full backup and a durable undo transaction spanning Hive boxes and images.
/// The encrypted journal is replayed before bootstrap on the next app start.
class FullBackupService {
  final HiveDBProvider db;
  final Directory documents;
  final Future<void> Function(String step)? afterWrite;
  bool _busy = false;
  bool _blocked = false;
  FullBackupService(this.db, this.documents, {this.afterWrite});

  bool get needsRecovery => _blocked;

  Future<Box<dynamic>> get _journal =>
      db.openScopedBox<dynamic>('RestoreJournal', '');

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy || _blocked) {
      throw StateError('Restore is busy or needs recovery');
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<List<Map<String, dynamic>>> _read(
    BackupDataset d,
    String suffix,
  ) async {
    try {
      return await d.read(db, suffix);
    } finally {
      await _close(d, suffix);
    }
  }

  Future<void> _close(BackupDataset d, String suffix) async {
    if (!d.global && suffix != db.activeBoxSuffix) {
      await d.close(db, suffix);
    }
  }

  Future<void> _replace(String name, String suffix, List<dynamic> rows) async {
    final d = datasetNamed(name);
    try {
      await d.replace(db, suffix, rows);
    } finally {
      await _close(d, suffix);
    }
  }

  Future<Map<String, dynamic>> _snapshot() async {
    final boxes = <Map<String, dynamic>>[];
    for (final d in backupDatasets.where((d) => d.global)) {
      boxes.add({'name': d.name, 'suffix': '', 'rows': await _read(d, '')});
    }
    for (final p in db.profileBox.values.toList()) {
      for (final d in backupDatasets.where((d) => !d.global)) {
        boxes.add({
          'name': d.name,
          'suffix': p.boxSuffix,
          'rows': await _read(d, p.boxSuffix),
        });
      }
    }
    final images = <String, String>{};
    var total = 0;
    for (final kind in UserImageKind.values) {
      final dir = Directory('${documents.path}/${kind.subdir}');
      if (await FileSystemEntity.isLink(dir.path)) {
        throw const FormatException('Image directory must not be a symlink');
      }
      if (!await dir.exists()) continue;
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) {
          throw const FormatException('Unexpected image entry');
        }
        final name = '${kind.subdir}/${entry.uri.pathSegments.last}';
        _checkImagePath(name);
        total += await entry.length();
        if (total > backupMaxBytes) {
          throw const FormatException('Backup too large');
        }
        images[name] = base64Encode(await entry.readAsBytes());
      }
    }
    return {
      'boxes': boxes,
      'images': images,
      'activeProfileId': db.activeProfileId,
    };
  }

  Future<Uint8List> export() => _exclusive(() async {
    final snapshot = await _snapshot();
    _validate(snapshot, complete: true);
    final images = Map<String, dynamic>.from(snapshot.remove('images') as Map);
    final archive = Archive();
    final entries = <String, dynamic>{};
    void add(String name, List<int> bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      entries[name] = {'bytes': bytes.length, 'crc32': getCrc32(bytes)};
    }

    add('data.json', utf8.encode(jsonEncode(snapshot)));
    for (final e in images.entries) {
      add(e.key, base64Decode(e.value as String));
    }
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'ont-full-backup',
        'version': 1,
        'createdUtc': DateTime.now().toUtc().toIso8601String(),
        'entries': entries,
        'counts': {
          for (final b in snapshot['boxes'])
            '${b['name']}/${b['suffix']}': (b['rows'] as List).length,
        },
        'excluded': ['public_caches', 'credentials', 'system_permissions'],
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    _checkArchiveSizes(archive);
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    if (bytes.length > backupMaxZipBytes) {
      throw const FormatException('Backup too large');
    }
    return bytes;
  });

  static Archive _decodeBoundedZip(Uint8List bytes) {
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    if (directory.fileHeaders.length > backupMaxEntries) {
      throw const FormatException('Too many ZIP entries');
    }
    final names = <String>{};
    var total = 0;
    for (final h in directory.fileHeaders) {
      total += h.uncompressedSize;
      if (total > backupMaxBytes ||
          h.uncompressedSize < 0 ||
          !names.add(h.filename) ||
          h.filename.endsWith('/') ||
          ((h.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
          h.filename.contains('\\') ||
          h.filename.contains('..') ||
          h.filename.contains('\u0000')) {
        throw const FormatException('Unsafe ZIP directory');
      }
    }
    final archive = Archive();
    for (final h in directory.fileHeaders) {
      final out = _BoundedOutput(h.uncompressedSize);
      h.file!.decompress(out);
      final content = out.getBytes();
      if (content.length != h.uncompressedSize ||
          getCrc32(content) != h.crc32) {
        throw const FormatException('ZIP size or CRC mismatch');
      }
      archive.addFile(ArchiveFile(h.filename, content.length, content));
    }
    return archive;
  }

  static void _reconcile(List<Map<String, dynamic>> boxes) {
    final app = boxes.firstWhere(
      (b) => b['name'] == HiveDBProvider.appConfigBoxName,
    );
    final appRows = app['rows'] as List;
    final c = appRows.isEmpty
        ? <String, dynamic>{}
        : appRows.first['value'] as Map;
    final offset = DayBoundaryCalc.totalMinutesOf(
      (c['dayStartOffsetHours'] as int?) ?? 0,
      (c['dayStartOffsetMinutes'] as int?) ?? 0,
    );
    for (final b in boxes.where(
      (b) => b['name'] == HiveDBProvider.intakeBoxName,
    )) {
      final tracked = boxes.firstWhere(
        (d) =>
            d['name'] == HiveDBProvider.trackedDayBoxName &&
            d['suffix'] == b['suffix'],
      );
      final days = <String, Map<String, dynamic>>{
        for (final r in tracked['rows'])
          DateTime.parse(r['value']['day'] as String).toParsedDay():
              Map<String, dynamic>.from(jsonDecode(jsonEncode(r)) as Map),
      };
      for (final r in days.values) {
        for (final f in [
          'caloriesTracked',
          'carbsTracked',
          'fatTracked',
          'proteinTracked',
        ]) {
          r['value'][f] = 0.0;
        }
      }
      for (final r in b['rows']) {
        final intake = IntakeEntity.fromIntakeDBO(
          IntakeDBO.fromJson(Map<String, dynamic>.from(r['value'] as Map)),
        );
        final time = intake.dateTime;
        final label = DayBoundaryCalc.storedMomentDayLabel(time, offset);
        final key = label.toParsedDay();
        final row = days.putIfAbsent(
          key,
          () => {
            'key': key,
            'value': TrackedDayDBO(
              day: label,
              calorieGoal: 0,
              caloriesTracked: 0,
            ).toJson(),
          },
        );
        final value = row['value'] as Map;
        final totals = {
          'caloriesTracked': intake.totalKcal,
          'carbsTracked': intake.totalCarbsGram,
          'fatTracked': intake.totalFatsGram,
          'proteinTracked': intake.totalProteinsGram,
        };
        for (final e in totals.entries) {
          value[e.key] = ((value[e.key] as num?) ?? 0) + e.value;
        }
      }
      tracked['rows'] = days.values.toList();
    }
  }

  static void _checkArchiveSizes(Archive archive) {
    var total = 0;
    final names = <String>{};
    if (archive.files.isEmpty || archive.length > backupMaxEntries) {
      throw const FormatException('Invalid archive size');
    }
    for (final entry in archive.files) {
      total += entry.size;
      if (!entry.isFile ||
          entry.size < 0 ||
          total > backupMaxBytes ||
          !names.add(entry.name)) {
        throw const FormatException('Invalid archive entry');
      }
    }
  }

  static void _checkImagePath(String path) {
    if (UserImageStorage.sanitizeRelative(path) != path ||
        path.contains('\\') ||
        path.contains('\u0000') ||
        path.split('/').last.length > 200) {
      throw const FormatException('Invalid image path');
    }
  }

  Future<RestorePreview> preview(Uint8List bytes) => _exclusive(() async {
    if (bytes.length > backupMaxZipBytes ||
        bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4b) {
      throw const FormatException('Not a supported ZIP backup');
    }
    // archive keeps entries compressed until content is read, so inspect
    // advertised inflated sizes before touching entry.content.
    final archive = _decodeBoundedZip(bytes);
    _checkArchiveSizes(archive);
    final manifestFile = archive.findFile('manifest.json');
    final legacy = manifestFile == null;
    final Map<String, dynamic> input;
    if (legacy) {
      input = LegacyBackupReader.read(archive, db);
    } else {
      final m =
          jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map;
      if (m['format'] != 'ont-full-backup' ||
          m['version'] is! int ||
          m['version'] != 1) {
        throw const FormatException('Unsupported backup version');
      }
      final entries = m['entries'] as Map;
      if (!entries.containsKey('data.json') ||
          entries.length != archive.length - 1) {
        throw const FormatException('Incomplete backup manifest');
      }
      for (final entry in archive.files.where(
        (e) => e.name != 'manifest.json',
      )) {
        final info = entries[entry.name] as Map?;
        if (info == null ||
            info['bytes'] != entry.size ||
            info['crc32'] != getCrc32(entry.content as List<int>)) {
          throw const FormatException('Backup checksum mismatch');
        }
        if (entry.name != 'data.json') _checkImagePath(entry.name);
      }
      input = Map<String, dynamic>.from(
        jsonDecode(
              utf8.decode(archive.findFile('data.json')!.content as List<int>),
            )
            as Map,
      );
      input['images'] = {
        for (final e in archive.files)
          if (e.name != 'data.json' && e.name != 'manifest.json')
            e.name: base64Encode(e.content as List<int>),
      };
      final actualCounts = {
        for (final b in input['boxes'])
          '${b['name']}/${b['suffix']}': (b['rows'] as List).length,
      };
      if (!const DeepCollectionEquality().equals(actualCounts, m['counts'])) {
        throw const FormatException('Backup record count mismatch');
      }
    }
    _validate(input, complete: !legacy);
    final before = await _snapshot();
    return await _plan(input, before, legacy);
  });

  void _validate(Map<String, dynamic> input, {required bool complete}) {
    final boxes = input['boxes'] as List;
    final seen = <String>{};
    final profiles = <ProfileDBO>[];
    final suffixes = <String>{};
    for (final b in boxes) {
      final name = b['name'] as String;
      final suffix = b['suffix'] as String;
      if (suffix.length > 100 ||
          !RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(suffix) ||
          !seen.add('$name/$suffix')) {
        throw const FormatException('Invalid box scope');
      }
      final d = datasetNamed(name);
      if (d.global && suffix.isNotEmpty) {
        throw const FormatException('Invalid global scope');
      }
      final rows = b['rows'] as List;
      d.validate(rows);
      if (name == HiveDBProvider.profileBoxName) {
        for (final row in rows) {
          final p = ProfileDBO.fromJson(
            Map<String, dynamic>.from(row['value'] as Map),
          );
          if (p.id.isEmpty ||
              row['key'] != p.id ||
              !suffixes.add(p.boxSuffix)) {
            throw const FormatException('Invalid profile registry');
          }
          profiles.add(p);
        }
      }
    }
    if (complete) {
      if (profiles.isEmpty) throw const FormatException('Missing profiles');
      final expected = {
        for (final d in backupDatasets.where((d) => d.global)) '${d.name}/',
        for (final p in profiles)
          for (final d in backupDatasets.where((d) => !d.global))
            '${d.name}/${p.boxSuffix}',
      };
      if (!const SetEquality<String>().equals(seen, expected)) {
        throw const FormatException('Missing or unexpected dataset');
      }
    }
    // No non-finite numbers or invalid photo references may cross into Hive.
    void walk(dynamic v, [String? key]) {
      if (v is num && !v.isFinite) {
        throw const FormatException('Non-finite number');
      }
      if (v is Map) {
        for (final e in v.entries) {
          walk(e.value, e.key.toString());
        }
      }
      if (v is List) {
        for (final item in v) {
          walk(item);
        }
      }
      if (v is String && (key == 'imagePath' || key == 'localImagePath')) {
        _checkImagePath(v);
        if (complete && !(input['images'] as Map).containsKey(v)) {
          throw const FormatException('Referenced image missing');
        }
      }
    }

    walk(boxes);
    for (final path in (input['images'] as Map).keys) {
      _checkImagePath(path as String);
    }
  }

  Future<RestorePreview> _plan(
    Map<String, dynamic> input,
    Map<String, dynamic> before,
    bool legacy,
  ) async {
    final original = (before['boxes'] as List).cast<Map<String, dynamic>>();
    final keep = <Map<String, dynamic>>[];
    final backup = <Map<String, dynamic>>[];
    var added = 0, conflicts = 0, unchanged = 0;
    final localProfiles = {for (final p in db.profileBox.values) p.id: p};
    final suffixMap = <String, String>{};
    final usedSuffixes = localProfiles.values.map((p) => p.boxSuffix).toSet();
    final incoming = jsonDecode(jsonEncode(input['boxes'])) as List;
    for (final b in incoming.where(
      (b) => b['name'] == HiveDBProvider.profileBoxName,
    )) {
      for (final row in b['rows']) {
        final p = ProfileDBO.fromJson(
          Map<String, dynamic>.from(row['value'] as Map),
        );
        final local = localProfiles[p.id];
        var suffix = local?.boxSuffix;
        if (suffix == null) {
          do {
            suffix = 'restore_${IdGenerator.getUniqueID()}';
          } while (!usedSuffixes.add(suffix));
        }
        suffixMap[p.boxSuffix] = suffix;
        row['value']['boxSuffix'] = suffix;
      }
    }
    // Legacy zips describe only the currently selected profile.
    if (legacy) suffixMap[db.activeBoxSuffix] = db.activeBoxSuffix;
    final journalBoxes = <Map<String, dynamic>>[];
    for (final b in incoming) {
      final d = datasetNamed(b['name'] as String);
      final suffix = d.global ? '' : suffixMap[b['suffix']];
      if (suffix == null) {
        throw const FormatException('Unregistered profile scope');
      }
      final local = original.firstWhereOrNull(
        (e) => e['name'] == d.name && e['suffix'] == suffix,
      );
      final rows = (local?['rows'] as List? ?? []).cast<Map<String, dynamic>>();
      journalBoxes.add({'name': d.name, 'suffix': suffix, 'rows': rows});
      final keepRows = [...rows];
      final backupRows = [...rows];
      final index = <String, int>{};
      for (var i = 0; i < rows.length; i++) {
        // Existing duplicate identities make a merge ambiguous; leave them intact.
        final id = d.rowIdentity(rows[i]);
        if (index.containsKey(id)) {
          throw const FormatException('Local duplicate identities');
        }
        index[id] = i;
      }
      final usedKeys = rows.map((r) => r['key']).toSet();
      for (final dynamic r in b['rows']) {
        final row = Map<String, dynamic>.from(r as Map);
        final id = d.rowIdentity(row);
        final i = index[id];
        if (i == null) {
          if (usedKeys.contains(row['key'])) {
            // Library and diary stores allow arbitrary Hive keys; key collisions
            // across devices must never silently overwrite unrelated identities.
            row['key'] = 'restore_${IdGenerator.getUniqueID()}';
          }
          usedKeys.add(row['key']);
          keepRows.add(row);
          backupRows.add(row);
          added++;
        } else if (const DeepCollectionEquality().equals(
          rows[i]['value'],
          row['value'],
        )) {
          unchanged++;
        } else {
          conflicts++;
          backupRows[i] = {'key': rows[i]['key'], 'value': row['value']};
        }
      }
      keep.add({'name': d.name, 'suffix': suffix, 'rows': keepRows});
      backup.add({'name': d.name, 'suffix': suffix, 'rows': backupRows});
    }
    final localImages = Map<String, dynamic>.from(before['images'] as Map);
    final incomingImages = Map<String, dynamic>.from(input['images'] as Map);
    var imageConflicts = 0;
    for (final e in incomingImages.entries) {
      if (localImages.containsKey(e.key) && localImages[e.key] != e.value) {
        imageConflicts++;
      }
    }
    final imageBefore = {
      for (final path in incomingImages.keys) path: localImages[path],
    };
    // Include untouched stores too: a changed shared day boundary also changes
    // their grouping, and rollback must cover the resulting derived totals.
    for (final b in original) {
      if (journalBoxes.any(
        (e) => e['name'] == b['name'] && e['suffix'] == b['suffix'],
      )) {
        continue;
      }
      journalBoxes.add(b);
      keep.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(b)) as Map));
      backup.add(Map<String, dynamic>.from(jsonDecode(jsonEncode(b)) as Map));
    }
    for (final target in [keep, backup]) {
      for (final b in target.where(
        (b) =>
            b['name'] == HiveDBProvider.appConfigBoxName ||
            b['name'] == HiveDBProvider.configBoxName,
      )) {
        final local = original.firstWhereOrNull(
          (e) => e['name'] == b['name'] && e['suffix'] == b['suffix'],
        );
        for (final row in b['rows']) {
          final rows = local?['rows'] as List? ?? [];
          final old = rows.firstWhereOrNull((r) => r['key'] == row['key']);
          // A backup cannot grant privacy consent on a different device.
          for (final field in [
            'hasAcceptedDisclaimer',
            'hasAcceptedPolicy',
            'hasAcceptedSendAnonymousData',
          ]) {
            row['value'][field] = old?['value'][field] ?? false;
          }
          row['value']['policyNoticeRevisionSeen'] =
              old?['value']['policyNoticeRevisionSeen'];
        }
      }
    }
    _reconcile(keep);
    _reconcile(backup);
    return RestorePreview._(
      legacy,
      Map.unmodifiable({
        for (final b in incoming)
          '${b['name']}/${b['suffix']}': (b['rows'] as List).length,
      }),
      added,
      conflicts,
      unchanged,
      imageConflicts,
      incomingImages.length,
      {'boxes': journalBoxes, 'images': imageBefore, 'fingerprint': before},
      {
        'boxes': keep,
        'images': {
          for (final e in incomingImages.entries)
            if (!localImages.containsKey(e.key) ||
                localImages[e.key] == e.value)
              e.key: e.value,
        },
      },
      {'boxes': backup, 'images': incomingImages},
    );
  }

  Future<void> restore(RestorePreview preview, RestoreConflictPolicy policy) =>
      _exclusive(() async {
        if (!const DeepCollectionEquality().equals(
          await _snapshot(),
          preview._before['fingerprint'],
        )) {
          throw StateError('Data changed after preview; preview again');
        }
        final journal = await _journal;
        if (journal.isNotEmpty) {
          _blocked = true;
          throw StateError('Pending recovery');
        }
        final before = Map<String, dynamic>.from(preview._before)
          ..remove('fingerprint');
        try {
          await journal.put('before', before);
          await journal.flush();
          await _apply(
            policy == RestoreConflictPolicy.keepLocal
                ? preview._afterKeep
                : preview._afterBackup,
            hooks: true,
          );
          await journal.clear();
          await journal.flush();
        } catch (_) {
          try {
            await _apply(before);
            await journal.clear();
            await journal.flush();
          } catch (_) {
            _blocked = true;
          }
          rethrow;
        }
      });

  Future<void> _apply(Map<String, dynamic> data, {bool hooks = false}) async {
    // Registry is written last, and restored last, so partially written new
    // profiles never become visible before their data has been flushed.
    final boxes = (data['boxes'] as List).toList()
      ..sort(
        (a, b) => (a['name'] == HiveDBProvider.profileBoxName ? 1 : 0)
            .compareTo(b['name'] == HiveDBProvider.profileBoxName ? 1 : 0),
      );
    for (final b in boxes) {
      await _replace(
        b['name'] as String,
        b['suffix'] as String,
        b['rows'] as List,
      );
      if (hooks) await afterWrite?.call(b['name'] as String);
    }
    for (final e in (data['images'] as Map).entries) {
      final path = e.key as String;
      _checkImagePath(path);
      final file = File('${documents.path}/$path');
      if (await FileSystemEntity.isLink(file.path) ||
          await FileSystemEntity.isLink(file.parent.path)) {
        throw const FormatException('Image target must not be a symlink');
      }
      if (e.value == null) {
        if (await file.exists()) await file.delete();
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(base64Decode(e.value as String), flush: true);
      }
      if (hooks) await afterWrite?.call(path);
    }
  }

  Future<void> recoverPendingRestore() async {
    final journal = await _journal;
    final pending = journal.get('before');
    if (pending == null) return;
    _blocked = true;
    await _apply(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(pending)) as Map),
    );
    await journal.clear();
    await journal.flush();
    _blocked = false;
  }
}

/// Checks output growth as well as ZIP headers, including LZ backreferences.
class _BoundedOutput extends OutputMemoryStream {
  final int limit;
  _BoundedOutput(this.limit);
  void _check(int count) {
    if (count < 0 || length + count > limit) {
      throw const FormatException('Inflated ZIP exceeds declared size');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
