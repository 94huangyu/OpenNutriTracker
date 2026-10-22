import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:opennutritracker/core/utils/user_image_draft.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform old;
  late File incoming;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ont-image-draft-');
    old = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    incoming = await File('${root.path}/incoming').writeAsBytes([4, 5, 6]);
  });
  tearDown(() async {
    PathProviderPlatform.instance = old;
    await root.delete(recursive: true);
  });
  for (final kind in [UserImageKind.meal, UserImageKind.recipe]) {
    test(
      '${kind.name}: cancel deletes only new files, keeping saved photo and credit',
      () async {
        final dir = await UserImageStorage.ensureDirectory(kind);
        final original = await File(
          '${dir.path}/original.webp',
        ).writeAsBytes([1, 2, 3]);
        final credit = await File(
          '${original.path}.credit.json',
        ).writeAsString('saved credit');
        final draft = UserImageDraft(kind);
        final first = await draft.importFrom(incoming.path);
        final second = await draft.importFrom(incoming.path);
        expect(first, isNot(second));
        await draft.dispose();
        expect(await File('${root.path}/$first').exists(), false);
        expect(await File('${root.path}/$second').exists(), false);
        expect(await original.readAsBytes(), [1, 2, 3]);
        expect(await credit.readAsString(), 'saved credit');
      },
    );
    test(
      '${kind.name}: successful save retains selected file and discards superseded drafts',
      () async {
        final draft = UserImageDraft(kind);
        final first = await draft.importFrom(incoming.path);
        final second = await draft.importFrom(incoming.path);
        draft.retain(second);
        await draft.dispose();
        expect(await File('${root.path}/$first').exists(), false);
        expect(await File('${root.path}/$second').readAsBytes(), [4, 5, 6]);
      },
    );
    test(
      '${kind.name}: an import completing after editor closes leaves no orphan',
      () async {
        final draft = UserImageDraft(kind);
        final pending = draft.importFrom(incoming.path);
        await draft.dispose();
        expect(await pending, isNull);
        final dir = await UserImageStorage.ensureDirectory(kind);
        expect(await dir.list().toList(), isEmpty);
        expect(await draft.importFrom(incoming.path), isNull);
      },
    );
  }
  test('failed source read cannot delete any saved file', () async {
    final dir = await UserImageStorage.ensureDirectory(UserImageKind.meal);
    final original = await File('${dir.path}/original.webp').writeAsBytes([1]);
    final draft = UserImageDraft(UserImageKind.meal);
    await expectLater(
      draft.importFrom('${root.path}/missing'),
      throwsA(isA<FileSystemException>()),
    );
    await draft.dispose();
    expect(await original.readAsBytes(), [1]);
    expect((await dir.list().toList()).length, 1);
  });
}
