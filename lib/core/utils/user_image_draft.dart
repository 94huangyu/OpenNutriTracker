import 'package:logging/logging.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';

/// Owns only new files created by one editor; saved snapshot files are untouched.
class UserImageDraft {
  final UserImageKind kind;
  final _paths = <String>{};
  String? _retained;
  bool _disposed = false;
  UserImageDraft(this.kind);

  Future<String?> importFrom(String sourcePath) async {
    if (_disposed) return null;
    final id = IdGenerator.getUniqueID();
    final path = UserImageStorage.relativePathFor(kind, id);
    _paths.add(path);
    try {
      await UserImageStorage.importFrom(
        kind: kind,
        ownerId: id,
        sourcePath: sourcePath,
      );
    } catch (_) {
      await _discard(path);
      rethrow;
    }
    if (_disposed) {
      await _discard(path);
      return null;
    }
    return path;
  }

  void retain(String? path) => _retained = path;

  Future<void> dispose() async {
    _disposed = true;
    for (final path in _paths.toList()) {
      if (path != _retained) await _discard(path);
    }
    // Saved originals may still be referenced by diary/ingredient snapshots.
    // shortcut: keep them until a reference-aware cleanup is implemented.
  }

  Future<void> _discard(String path) async {
    try {
      await UserImageStorage.delete(path);
      _paths.remove(path);
    } catch (error, stack) {
      Logger(
        'UserImageDraft',
      ).warning('Could not remove a draft photo', error, stack);
    }
  }
}
