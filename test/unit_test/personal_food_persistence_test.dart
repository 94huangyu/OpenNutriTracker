import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/util/meal_relevance_ranker.dart';
import '../helpers/hive_test_setup.dart';
import '../helpers/personal_food_fixture.dart';

void main() {
  late Directory dir;
  late Box<MealDBO> box;
  late PersonalFoodDataSource store;
  setUp(() async {
    registerHiveAdaptersOnce();
    dir = await Directory.systemTemp.createTemp('ont-personal-');
    Hive.init(dir.path);
    box = await Hive.openBox<MealDBO>(
      'personal',
      encryptionCipher: HiveAesCipher(List.filled(32, 7)),
    );
    store = PersonalFoodDataSource(box);
  });
  tearDown(() async {
    store.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'favorite is separate from review and survives encrypted reopen',
    () async {
      final original = food();
      final saved = await store.setFavorite(original, true);
      expect(saved.isFavorite, isTrue);
      expect(saved.isPersonallyReviewed, isFalse);
      await box.close();
      box = await Hive.openBox<MealDBO>(
        'personal',
        encryptionCipher: HiveAesCipher(List.filled(32, 7)),
      );
      store.dispose();
      store = PersonalFoodDataSource(box);
      expect(store.apply(original).isFavorite, isTrue);
      expect(store.apply(original).nutriments.energyKcal100, 80);
      await store.setFavorite(original, false);
      expect(store.apply(saved).isFavorite, isFalse);
    },
  );

  test(
    'review requires evidence and clearing cannot be revived by old snapshot',
    () async {
      final original = food();
      await expectLater(
        store.review(original, 'package', '  '),
        throwsArgumentError,
      );
      await expectLater(
        store.review(original, 'automatic', 'test'),
        throwsArgumentError,
      );
      final reviewed = await store.review(
        original,
        'package',
        ' 对照包装全部已填项 ',
        now: DateTime.utc(2026, 10, 20),
      );
      expect(reviewed.isPersonallyReviewed, isTrue);
      expect(reviewed.isFavorite, isFalse);
      expect(reviewed.reviewNote, '对照包装全部已填项');
      await store.setFavorite(reviewed, true);
      expect(store.apply(original).reviewedAt, DateTime.utc(2026, 10, 20));
      await store.clearReview(reviewed);
      expect(store.apply(reviewed).isPersonallyReviewed, isFalse);
      expect(store.apply(reviewed).isFavorite, isTrue);
    },
  );

  test(
    'changes invalidate evidence; favorite persists; identities do not collide',
    () async {
      final original = food();
      await store.setFavorite(original, true);
      await store.review(original, 'package', 'label');
      expect(store.apply(food(energy: 81)).isPersonallyReviewed, isFalse);
      expect(store.apply(food(energy: 81)).isFavorite, isTrue);
      expect(
        store.apply(food(source: MealSourceEntity.custom)).isFavorite,
        isFalse,
      );
      expect(
        store
            .apply(food(source: MealSourceEntity.fdc, backend: 'bls'))
            .isFavorite,
        isFalse,
      );
      await store.review(
        food(source: MealSourceEntity.fdc, backend: 'bls'),
        'reference',
        'table',
      );
      expect(
        store
            .apply(food(source: MealSourceEntity.fdc, backend: 'fdc'))
            .isPersonallyReviewed,
        isFalse,
      );
      final snapshot = jsonEncode(MealDBO.fromMealEntity(original).toJson());
      await store.updateTemplate(original, food(code: 'new', energy: 90));
      expect(store.apply(food(code: 'new', energy: 90)).isFavorite, isTrue);
      expect(
        store.apply(food(code: 'new', energy: 90)).isPersonallyReviewed,
        isFalse,
      );
      expect(jsonEncode(MealDBO.fromMealEntity(original).toJson()), snapshot);
    },
  );

  test(
    'Hive/JSON/CSV preserve evidence, all nutrition and multiline note; legacy absent fields',
    () async {
      final original = food(source: MealSourceEntity.fdc, backend: 'bls');
      final reviewed = await store.review(
        original,
        'reference',
        '表格,"牛奶"\n2026版',
      );
      final json =
          jsonDecode(jsonEncode(MealDBO.fromMealEntity(reviewed).toJson()))
              as Map<String, dynamic>;
      final restored = MealDBO.fromJson(json);
      final csv = CsvDataExporter.mealsToCsv([restored]);
      final read = CsvDataExporter.parseMealsFromCsv(csv).single;
      expect(
        jsonDecode(jsonEncode(read.toJson())),
        jsonDecode(jsonEncode(restored.toJson())),
      );
      for (final key in [
        'isFavorite',
        'reviewSource',
        'reviewNote',
        'reviewedAt',
      ]) {
        json.remove(key);
      }
      final old = MealEntity.fromMealDBO(MealDBO.fromJson(json));
      expect(old.isFavorite, isFalse);
      expect(old.isPersonallyReviewed, isFalse);
      expect(old.nutriments.vitaminA100, 300);
      await store.importMeals([read]);
      expect(store.apply(original).reviewNote, reviewed.reviewNote);
      await box.close();
      box = await Hive.openBox<MealDBO>(
        'personal',
        encryptionCipher: HiveAesCipher(List.filled(32, 7)),
      );
      store.dispose();
      store = PersonalFoodDataSource(box);
      expect(store.apply(original).isPersonallyReviewed, isTrue);
    },
  );

  test(
    'invalid import batch writes nothing and public identity is mandatory',
    () async {
      final invalid = food().withPersonalState(
        isFavorite: true,
        reviewSource: 'package',
      );
      await expectLater(
        store.importMeals([
          MealDBO.fromMealEntity(food()),
          MealDBO.fromMealEntity(invalid),
        ]),
        throwsFormatException,
      );
      expect(store.getAll(), isEmpty);
      await expectLater(
        store.setFavorite(food(code: ''), true),
        throwsArgumentError,
      );
    },
  );

  test(
    'review first, personal next, favorite next; no collapse of personal IDs',
    () {
      final own = food(source: MealSourceEntity.custom);
      final favorite = food(
        code: 'favorite',
      ).withPersonalState(isFavorite: true);
      final reviewed = food(code: 'reviewed').withPersonalState(
        isFavorite: false,
        reviewSource: 'package',
        reviewNote: 'label',
        reviewedAt: DateTime.utc(2026),
      );
      final public = food(code: 'public');
      final result = mergeAndRankMeals(
        [public, favorite, own, reviewed],
        [],
        '牛奶',
      );
      expect(result.map((m) => m.code).toList(), [
        'reviewed',
        'same',
        'favorite',
        'public',
      ]);
    },
  );
}
