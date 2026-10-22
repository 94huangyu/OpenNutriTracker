import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/export_write_verifier.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FullBackupScreen extends StatefulWidget {
  final FullBackupService? service;
  final Future<Uint8List?> Function()? pickBackup;
  final Future<bool> Function(Uint8List)? saveBackup;
  final Future<void> Function()? onRestored;
  const FullBackupScreen({
    super.key,
    this.service,
    this.pickBackup,
    this.saveBackup,
    this.onRestored,
  });
  @override
  State<FullBackupScreen> createState() => _FullBackupScreenState();
}

class _FullBackupScreenState extends State<FullBackupScreen> {
  late final FullBackupService _service =
      widget.service ?? locator<FullBackupService>();
  bool _busy = false;
  RestorePreview? _preview;
  RestoreConflictPolicy _policy = RestoreConflictPolicy.keepLocal;
  String? _message;
  bool _error = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _service.needsRecovery
              ? S.of(context).m4RecoveryRequired
              : e is FormatException
              ? S.of(context).m4InvalidBackup
              : e is StateError
              ? S.of(context).m4PreviewChanged
              : S.of(context).m4OperationFailed;
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _run(() async {
    final Uint8List? bytes;
    if (widget.pickBackup != null) {
      bytes = await widget.pickBackup!();
    } else {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      if (await file.length() > backupMaxZipBytes) {
        throw const FormatException('ZIP too large');
      }
      bytes = await file.readAsBytes();
    }
    if (bytes == null) return;
    final p = await _service.preview(bytes);
    if (mounted) {
      setState(() {
        _preview = p;
        _policy = RestoreConflictPolicy.keepLocal;
      });
    }
  });

  Future<void> _export() => _run(() async {
    final bytes = await _service.export();
    final saved = widget.saveBackup != null
        ? await widget.saveBackup!(bytes)
        : await _save(bytes);
    if (saved && mounted) {
      setState(() => _message = S.of(context).m4ExportSuccess);
    }
  });

  Future<bool> _save(Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      fileName: 'ont-full-backup.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: bytes,
    );
    if (path == null) return false;
    ExportWriteVerifier.verify(path, bytes.length);
    return true;
  }

  Future<void> _restore() => _run(() async {
    final preview = _preview;
    if (preview == null) return;
    await _service.restore(preview, _policy);
    if (!mounted) return;
    setState(() {
      _preview = null;
      _message = S.of(context).m4RestoreSuccess;
    });
    try {
      await widget.onRestored?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = S.of(context).m4RefreshFailed;
        });
      }
    }
  });

  Future<void> _csv() => _run(() async {
    final saved = await locator<ExportDataUsecase>().exportData(
      'ont-data-csv.zip',
      'user_activity.json',
      'user_intake.json',
      'user_tracked_day.json',
      'user_recipes.json',
      'weight_log.json',
      'custom_activity_templates.json',
      format: ExportFormat.csv,
    );
    if (mounted && saved) {
      setState(() => _message = S.of(context).m4ExportSuccess);
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = _preview;
    return PopScope(
      canPop: !_busy && !_service.needsRecovery,
      child: Scaffold(
        appBar: AppBar(title: Text(s.m4BackupTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(s.m4BackupDescription),
              const SizedBox(height: 12),
              Text(
                s.m4BackupPrivacy,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _error
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              if (_service.needsRecovery)
                Semantics(
                  identifier: 'backup-recover',
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _service.recoverPendingRestore();
                            if (mounted) {
                              setState(() => _message = s.m4RecoverySuccess);
                            }
                          }),
                    child: Text(s.m4Recover),
                  ),
                )
              else ...[
                Semantics(
                  identifier: 'backup-export-full',
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.save_alt),
                    label: Text(s.m4ExportFull),
                  ),
                ),
                Semantics(
                  identifier: 'backup-pick-restore',
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.restore),
                    label: Text(s.m4ChooseRestore),
                  ),
                ),
              ],
              if (p != null) ...[
                const Divider(height: 32),
                Text(
                  s.m4RestorePreview,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (p.legacy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.m4LegacyWarning),
                  ),
                ..._counts(s, p).entries.map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key),
                    trailing: Text('${e.value}'),
                  ),
                ),
                Text(s.m4RestoreRules),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('${s.m4New}: ${p.added}'),
                    Text('${s.m4Conflicts}: ${p.conflicts}'),
                    Text('${s.m4Unchanged}: ${p.unchanged}'),
                    Text('${s.m4ImageConflicts}: ${p.imageConflicts}'),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'backup-conflict-policy',
                  child: DropdownButtonFormField<RestoreConflictPolicy>(
                    initialValue: _policy,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: RestoreConflictPolicy.keepLocal,
                        child: Text(s.m4KeepLocal),
                      ),
                      DropdownMenuItem(
                        value: RestoreConflictPolicy.useBackup,
                        child: Text(s.m4UseBackup),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _policy = v!),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  identifier: 'backup-confirm-restore',
                  child: FilledButton(
                    onPressed: _busy ? null : _restore,
                    child: Text(s.m4RestoreConfirm),
                  ),
                ),
                Semantics(
                  identifier: 'backup-cancel-preview',
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _preview = null),
                    child: Text(s.dialogCancelLabel),
                  ),
                ),
              ],
              const Divider(height: 32),
              Text(s.m4CsvDescription),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'backup-export-csv',
                child: OutlinedButton(
                  onPressed: _busy || _service.needsRecovery ? null : _csv,
                  child: Text(s.m4ExportCsv),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, int> _counts(S s, RestorePreview p) {
    final labels = {
      'ProfileBox': s.m4Profiles,
      'AppConfigBox': s.m4Settings,
      'ConfigBox': s.m4Settings,
      'CustomMealBox': s.m4Foods,
      'PersonalFoodBox': s.m4PersonalFoods,
      'RecipeBox': s.m4Recipes,
      'IntakeBox': s.m4Intakes,
      'TrackedDayBox': s.m4DailyTotals,
      'WaterIntakeBox': s.m4WaterFasting,
      'FastingBox': s.m4WaterFasting,
    };
    final result = <String, int>{s.m4Images: p.imageFiles};
    for (final e in p.counts.entries) {
      final label = labels[e.key.split('/').first] ?? s.m4Historical;
      result[label] = (result[label] ?? 0) + e.value;
    }
    return result;
  }
}
