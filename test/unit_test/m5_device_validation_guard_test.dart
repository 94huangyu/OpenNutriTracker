import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:opennutritracker/features/settings/domain/backup/backup_dataset.dart';
import 'package:opennutritracker/features/settings/domain/backup/full_backup_service.dart';
import '../../tools/validation/m5_isolated_restore.dart';
import '../helpers/full_backup_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final package in [
    'com.opennutritracker.ont.opennutritracker',
    'com.opennutritracker.ont.opennutritracker.develop',
    '$validationPackage.extra',
    '',
  ]) {
    test('device probe refuses $package before opening data', () {
      expect(() => requireValidationPackage(package), throwsStateError);
    });
  }
  test('only the dedicated validation identity is accepted', () {
    expect(() => requireValidationPackage(validationPackage), returnsNormally);
  });
  test(
    'full restore into empty stores preserves all data across new scopes',
    () async {
      final fixture = await FullBackupFixture.open();
      addTearDown(fixture.close);
      final bytes = await fixture.service.export();
      final before = portableSnapshot(bytes);
      for (final dataset in backupDatasets) {
        final box = await dataset.open(fixture.db, '');
        await box.clear();
      }
      await fixture.service.restore(
        await fixture.service.preview(bytes),
        RestoreConflictPolicy.useBackup,
      );
      final after = portableSnapshot(await fixture.service.export());
      expect(
        after,
        isNot(before),
        reason: 'New profile storage suffix is intentional',
      );
      expect(canonicalProfileScopes(after), canonicalProfileScopes(before));
      expect((await fixture.service.preview(bytes)).added, 0);
      final changed = portableSnapshot(await fixture.service.export());
      final data = changed['data.json'] as Map;
      final box = (data['boxes'] as List).firstWhere(
        (b) => b['name'] == 'IntakeBox',
      );
      box['rows'][0]['value']['amount'] = 999;
      expect(
        canonicalProfileScopes(changed),
        isNot(canonicalProfileScopes(before)),
        reason: 'Canonicalisation must still detect lost or altered records',
      );
    },
  );
  test(
    'synthetic encrypted fixture reopens after closing the process stores',
    () async {
      final paths = PathProviderPlatform.instance;
      final fixture = await FullBackupFixture.open();
      final before = portableSnapshot(await fixture.service.export());
      await Hive.close();
      final reopened = await FullBackupFixture.reopen(fixture.root);
      try {
        expect(portableSnapshot(await reopened.service.export()), before);
        expect(reopened.db.intakeBox.length, 1);
      } finally {
        await reopened.close();
        PathProviderPlatform.instance = paths;
      }
    },
  );
}
