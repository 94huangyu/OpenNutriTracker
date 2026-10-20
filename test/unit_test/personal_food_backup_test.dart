import 'dart:io';
import 'dart:convert';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import '../helpers/hive_test_setup.dart';
import '../helpers/personal_food_fixture.dart';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/weight_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/fake_hive_db_provider.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class _StubUserActivityRepository extends UserActivityRepository {
  _StubUserActivityRepository()
    : super(UserActivityDataSource(FakeHiveDBProvider()));

  @override
  Future<List<UserActivityDBO>> getAllUserActivityDBO() async => [];
  @override
  Future<void> addAllUserActivityDBOs(List<UserActivityDBO> rows) async {}
}

class _StubIntakeRepository extends IntakeRepository {
  _StubIntakeRepository(this._intakes)
    : super(IntakeDataSource(FakeHiveDBProvider()));

  final List<IntakeDBO> _intakes;

  @override
  Future<List<IntakeDBO>> getAllIntakesDBO() async => _intakes;
  @override
  Future<void> addAllIntakeDBOs(List<IntakeDBO> rows) async {}
}

class _StubTrackedDayRepository extends TrackedDayRepository {
  _StubTrackedDayRepository()
    : super(TrackedDayDataSource(FakeHiveDBProvider()));

  @override
  Future<List<TrackedDayDBO>> getAllTrackedDaysDBO() async => [];
  @override
  Future<void> addAllTrackedDays(List<TrackedDayDBO> rows) async {}
}

class _StubRecipeRepository extends RecipeRepository {
  _StubRecipeRepository() : super(RecipeDataSource(FakeHiveDBProvider()));

  @override
  List<RecipeDBO> getAllRecipesDBO() => [];
  @override
  Future<void> addAllRecipeDBOs(List<RecipeDBO> rows) async {}
}

class _StubCustomMealDataSource extends CustomMealDataSource {
  _StubCustomMealDataSource(this._meals) : super(FakeHiveDBProvider());

  final List<MealDBO> _meals;

  @override
  List<MealDBO> getAllCustomMeals() => _meals;
}

class _StubWeightLogRepository extends WeightLogRepository {
  _StubWeightLogRepository() : super(WeightLogDataSource(FakeHiveDBProvider()));

  @override
  Future<List<WeightLogDBO>> getAllEntriesDBO() async => [];
  @override
  Future<void> addAllEntries(List<WeightLogDBO> rows) async {}
}

class _StubTemplateRepository extends CustomActivityTemplateRepository {
  _StubTemplateRepository()
    : super(CustomActivityTemplateDataSource(FakeHiveDBProvider()));

  @override
  Future<List<CustomActivityTemplateDBO>> allTemplateDBOs() async => [];
  @override
  Future<void> addAllTemplateDBOs(List<CustomActivityTemplateDBO> rows) async {}
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.uri);
  @override
  final Uri uri;
  @override
  String get name => 'backup.zip';
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => null;
  @override
  Future<int> length() => File(path!).length();
  @override
  Future<Uint8List> readAsBytes() => File(path!).readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() => File(path!).openRead().cast();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final format in ExportFormat.values) {
    test(
      'personal food archive round trip, no intake required: $format',
      () async {
        registerHiveAdaptersOnce();
        final root = await Directory.systemTemp.createTemp(
          'ont-personal-backup-',
        );
        Hive.init(root.path);
        final box = await Hive.openBox<MealDBO>('personal');
        final store = PersonalFoodDataSource(box);
        final originalProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProvider(root.path);
        addTearDown(() async {
          PathProviderPlatform.instance = originalProvider;
          store.dispose();
          await Hive.close();
          await root.delete(recursive: true);
        });
        final original = food();
        await store.setFavorite(original, true);
        await store.review(
          original,
          'package',
          '包装,"牛奶"\n逐项核对',
          now: DateTime.utc(2026, 10, 20),
        );
        final expected = jsonEncode(store.exportMeals().single.toJson());
        final exporter = ExportDataUsecase(
          _StubUserActivityRepository(),
          _StubIntakeRepository([]),
          _StubTrackedDayRepository(),
          _StubRecipeRepository(),
          _StubCustomMealDataSource([]),
          _StubWeightLogRepository(),
          _StubTemplateRepository(),
          personalFoods: store,
        );
        final archive = await exporter.assembleArchive(
          format: format,
          userActivityJsonFileName: 'activity.json',
          userIntakeJsonFileName: 'intake.json',
          trackedDayJsonFileName: 'days.json',
          recipeJsonFileName: 'recipes.json',
          weightLogJsonFileName: 'weights.json',
          customActivityTemplateJsonFileName: 'templates.json',
        );
        final entryName = format == ExportFormat.json
            ? 'personal_foods.json'
            : 'personal_foods.csv';
        expect(archive.findFile(entryName), isNotNull);
        final file = File('${root.path}/backup.zip');
        await file.writeAsBytes(ZipEncoder().encode(archive));
        await store.remove(original);
        final importer = ImportDataUsecase(
          _StubUserActivityRepository(),
          _StubIntakeRepository([]),
          _StubTrackedDayRepository(),
          _StubRecipeRepository(),
          _StubWeightLogRepository(),
          _StubTemplateRepository(),
          personalFoods: store,
          pickFile: () async => _PickedFile(file.uri),
        );
        if (format == ExportFormat.json) {
          await importer.importData(
            'activity.json',
            'intake.json',
            'days.json',
            'recipes.json',
            'weights.json',
            'templates.json',
          );
        } else {
          await importer.importDataCsv();
        }
        expect(jsonEncode(store.exportMeals().single.toJson()), expected);
        // Older archives omit this optional file; existing choices stay intact.
        final legacy = Archive();
        for (final entry in archive.files) {
          if (entry.name != entryName) legacy.addFile(entry);
        }
        await file.writeAsBytes(ZipEncoder().encode(legacy));
        if (format == ExportFormat.json) {
          await importer.importData(
            'activity.json',
            'intake.json',
            'days.json',
            'recipes.json',
            'weights.json',
            'templates.json',
          );
        } else {
          await importer.importDataCsv();
        }
        expect(jsonEncode(store.exportMeals().single.toJson()), expected);
      },
    );
  }
}
