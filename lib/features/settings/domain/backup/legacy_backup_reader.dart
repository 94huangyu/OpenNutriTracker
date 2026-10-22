import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/off_micronutrient_repair.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// Reads the original partial ZIP without performing any writes. It joins the
/// same validation, preview, stable-identity merge and rollback as full backups.
class LegacyBackupReader {
  static Map<String, dynamic> read(Archive archive, HiveDBProvider db) {
    final boxes = <Map<String, dynamic>>[];
    final csv = archive.findFile('user_intake.json') == null;
    final known = <String>{};
    void add<T>(
      String stem,
      String box,
      T Function(Map<String, dynamic>) decode,
      Map<String, dynamic> Function(T) encode,
      dynamic Function(T) key, {
      bool required = false,
      bool global = false,
      List<T> Function(String)? parseCsv,
      T Function(T)? repair,
    }) {
      final filename = '$stem.${csv ? 'csv' : 'json'}';
      final file = archive.findFile(filename);
      if (file == null) {
        if (required) throw FormatException('Missing $filename');
        return;
      }
      known.add(filename);
      final text = utf8.decode(file.content as List<int>);
      final List<T> values;
      if (csv) {
        if (parseCsv == null) {
          throw const FormatException('Unsupported CSV dataset');
        }
        values = parseCsv(text);
      } else {
        values = (jsonDecode(text) as List)
            .map((v) => decode(Map<String, dynamic>.from(v as Map)))
            .toList();
      }
      final repaired = repair == null ? values : values.map(repair).toList();
      boxes.add({
        'name': box,
        'suffix': global ? '' : db.activeBoxSuffix,
        'rows': [
          for (final v in repaired) {'key': key(v), 'value': encode(v)},
        ],
      });
    }

    add<UserActivityDBO>(
      'user_activity',
      HiveDBProvider.userActivityBoxName,
      UserActivityDBO.fromJson,
      (v) => v.toJson(),
      (v) => v.id,
      required: true,
      parseCsv: CsvDataExporter.parseUserActivitiesFromCsv,
    );
    add<IntakeDBO>(
      'user_intake',
      HiveDBProvider.intakeBoxName,
      IntakeDBO.fromJson,
      (v) => v.toJson(),
      (v) => v.id,
      required: true,
      parseCsv: CsvDataExporter.parseIntakesFromCsv,
      repair: OffMicronutrientRepair.repairIntake,
    );
    add<TrackedDayDBO>(
      'user_tracked_day',
      HiveDBProvider.trackedDayBoxName,
      TrackedDayDBO.fromJson,
      (v) => v.toJson(),
      (v) => v.day.toParsedDay(),
      required: true,
      parseCsv: CsvDataExporter.parseTrackedDaysFromCsv,
    );
    add<MealDBO>(
      'personal_foods',
      HiveDBProvider.personalFoodBoxName,
      MealDBO.fromJson,
      (v) => v.toJson(),
      (v) => MealEntity.fromMealDBO(v).personalKey,
      global: true,
      parseCsv: CsvDataExporter.parseMealsFromCsv,
      repair: OffMicronutrientRepair.repairMeal,
    );
    if (!csv) {
      add<RecipeDBO>(
        'user_recipes',
        HiveDBProvider.recipeBoxName,
        RecipeDBO.fromJson,
        (v) => v.toJson(),
        (v) => v.id,
        global: true,
        repair: OffMicronutrientRepair.repairRecipe,
      );
      add<WeightLogDBO>(
        'weight_log',
        HiveDBProvider.weightLogBoxName,
        WeightLogDBO.fromJson,
        (v) => v.toJson(),
        (v) => v.date.toParsedDay(),
      );
      add<CustomActivityTemplateDBO>(
        'custom_activity_templates',
        HiveDBProvider.customActivityTemplateBoxName,
        CustomActivityTemplateDBO.fromJson,
        (v) => v.toJson(),
        (v) => v.name,
        global: true,
      );
    }
    final images = <String, String>{};
    for (final entry in archive.files) {
      if (known.contains(entry.name)) continue;
      if (!UserImageStorage.isUserImagePath(entry.name)) {
        throw const FormatException('Unexpected legacy archive entry');
      }
      images[entry.name] = base64Encode(entry.content as List<int>);
    }
    // Normalise nested JSON DBOs before validation or comparison.
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode({'boxes': boxes, 'images': images})) as Map,
    );
  }
}
