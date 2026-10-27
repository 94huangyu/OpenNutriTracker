import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/change_recorded_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async => const ConfigEntity(
    false,
    false,
    false,
    AppThemeEntity.system,
    dayStartOffsetHours: 6,
  );
}

class _Days extends AddTrackedDayUsecase {
  bool failOnce = false;
  _Days(super.repo);
  @override
  Future<void> reconcileDayTracked(
    DateTime d,
    double k,
    double c,
    double f,
    double p,
  ) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('simulated write failure');
    }
    await super.reconcileDayTracked(d, k, c, f, p);
  }
}

class _FailingIntakes extends IntakeRepository {
  int writes = 0;
  _FailingIntakes(super.source);
  @override
  Future<void> addIntake(IntakeEntity item) async {
    await super.addIntake(item);
    if (++writes == 2) throw StateError('simulated partial batch write');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<IntakeDBO> box;
  late IntakeRepository repo;
  late TrackedDayRepository dayRepo;
  late _Days days;
  late ChangeRecordedIntakeUsecase changes;
  final day = DateTime(2026, 10, 15);
  final meal = MealEntity(
    code: 'snapshot',
    name: '薯片',
    url: null,
    mealQuantity: '60',
    mealUnit: 'g',
    servingQuantity: 15,
    servingUnit: 'g',
    servingSize: '',
    nutritionBasisQuantity: 15,
    source: MealSourceEntity.custom,
    nutriments: MealNutrimentsEntity(
      energyKcal100: 80 / 15 * 100,
      carbohydrates100: 40,
      fat100: 20,
      proteins100: 10,
      sugars100: null,
      saturatedFat100: 0,
      fiber100: null,
      vitaminB12100: 2.5,
    ),
  );
  final intake = IntakeEntity(
    id: 'original',
    unit: 'serving',
    amount: 7.5,
    type: IntakeTypeEntity.dinner,
    meal: meal,
    dateTime: DateTime(2026, 10, 16, 2),
  );
  setUp(() async {
    registerHiveAdaptersOnce();
    dir = await Directory.systemTemp.createTemp('ont-undo-');
    Hive.init(dir.path);
    box = await Hive.openBox<IntakeDBO>('intakes');
    final dayBox = await Hive.openBox<TrackedDayDBO>('days');
    final db = FakeHiveDBProvider(intakeBox: box, trackedDayBox: dayBox);
    repo = IntakeRepository(IntakeDataSource(db));
    dayRepo = TrackedDayRepository(TrackedDayDataSource(db));
    days = _Days(dayRepo);
    changes = ChangeRecordedIntakeUsecase(repo, days, _Config());
    await days.addNewTrackedDay(day, 0, 0, 0, 0);
    await changes.restore(intake, day);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
    'delete and concurrent/retried undo restore exact snapshot and totals once',
    () async {
      await changes.delete(intake, day);
      expect(box.isEmpty, true);
      expect((await dayRepo.getTrackedDay(day))!.caloriesTracked, 0);
      await Future.wait([
        changes.restore(intake, day),
        changes.restore(intake, day),
      ]);
      expect(box.length, 1);
      expect(
        jsonDecode(jsonEncode(box.values.single.toJson())),
        jsonDecode(jsonEncode(IntakeDBO.fromIntakeEntity(intake).toJson())),
      );
      final actual = (await dayRepo.getTrackedDay(day))!;
      expect(actual.caloriesTracked, closeTo(40, 1e-9));
      expect(actual.carbsTracked, 3);
      expect(actual.fatTracked, 1.5);
      expect(actual.proteinTracked, .75);
      await box.close();
      box = await Hive.openBox<IntakeDBO>('intakes');
      expect(box.values.single.unit, 'serving');
      expect(box.values.single.meal.nutriments.vitaminB12100, 2.5);
    },
  );
  test('repeat has a new id; deleting it never deletes the original', () async {
    await changes.repeat(intake, day, 30, 'g');
    expect(box.length, 2);
    final copy = (await repo.getAllIntakesDBO()).singleWhere(
      (i) => i.id != intake.id,
    );
    expect(copy.amount, 30);
    expect(copy.unit, 'g');
    expect(
      jsonDecode(jsonEncode(copy.meal.toJson())),
      jsonDecode(jsonEncode(IntakeDBO.fromIntakeEntity(intake).meal.toJson())),
    );
    expect(
      (await dayRepo.getTrackedDay(day))!.caloriesTracked,
      closeTo(200, 1e-9),
    );
    await changes.delete(IntakeEntity.fromIntakeDBO(copy), day);
    expect(box.values.single.id, intake.id);
    expect(
      (await dayRepo.getTrackedDay(day))!.caloriesTracked,
      closeTo(40, 1e-9),
    );
  });
  test(
    'failed day write compensates delete; failed undo stays retryable',
    () async {
      days.failOnce = true;
      await expectLater(changes.delete(intake, day), throwsStateError);
      expect(box.values.single.id, intake.id);
      expect(
        (await dayRepo.getTrackedDay(day))!.caloriesTracked,
        closeTo(40, 1e-9),
      );
      await changes.delete(intake, day);
      days.failOnce = true;
      await expectLater(changes.restore(intake, day), throwsStateError);
      expect(box.isEmpty, true);
      expect((await dayRepo.getTrackedDay(day))!.caloriesTracked, 0);
      await changes.restore(intake, day);
      expect(box.length, 1);
    },
  );
  test(
    'legacy records without a tracked-day row regain totals without body goals',
    () async {
      await Hive.box<TrackedDayDBO>('days').clear();
      await changes.repeat(intake, day, 7.5, 'serving');
      final tracked = (await dayRepo.getTrackedDay(day))!;
      expect(tracked.calorieGoal, 0);
      expect(tracked.caloriesTracked, closeTo(80, 1e-9));
    },
  );
  test('record editing persists the selected unit across a reopen', () async {
    await repo.updateIntake(intake.id, {'amount': 30.0, 'unit': 'g'});
    await box.close();
    box = await Hive.openBox<IntakeDBO>('intakes');
    expect(box.values.single.amount, 30);
    expect(box.values.single.unit, 'g');
  });
  test(
    'batch copy uses explicit destination day and meal under a 6am boundary',
    () async {
      final target = DateTime(2026, 10, 20);
      await changes.copySelected(
        [intake, intake],
        target,
        IntakeTypeEntity.lunch,
      );
      final copies = await repo.getIntakeByDateAndType(
        IntakeTypeEntity.lunch,
        target,
        dayStartOffsetHours: 6,
      );
      expect(copies, hasLength(2));
      expect(copies.map((i) => i.id).toSet(), hasLength(2));
      for (final copy in copies) {
        expect(copy.dateTime, target);
        expect(copy.amount, intake.amount);
        expect(copy.unit, intake.unit);
        expect(copy.meal.nutriments.vitaminB12100, 2.5);
      }
      expect(
        (await dayRepo.getTrackedDay(day))!.caloriesTracked,
        closeTo(40, 1e-9),
      );
      expect(
        (await dayRepo.getTrackedDay(target))!.caloriesTracked,
        closeTo(80, 1e-9),
      );
      await repo.updateIntake(copies.first.id, {'amount': 30.0, 'unit': 'g'});
      expect((await repo.getIntakeById(intake.id))!.amount, 7.5);
      expect((await repo.getIntakeById(intake.id))!.unit, 'serving');
      await changes.deleteSelected(copies, target);
      expect((await dayRepo.getTrackedDay(target))!.caloriesTracked, 0);
      expect(box.values.single.id, intake.id);
      expect(
        (await dayRepo.getTrackedDay(day))!.caloriesTracked,
        closeTo(40, 1e-9),
      );
    },
  );

  test(
    'batch failure restores all records and totals and can be retried',
    () async {
      days.failOnce = true;
      final target = DateTime(2026, 10, 21);
      await expectLater(
        changes.copySelected([intake, intake], target, IntakeTypeEntity.snack),
        throwsStateError,
      );
      expect(box.values.single.id, intake.id);
      expect((await dayRepo.getTrackedDay(target))!.caloriesTracked, 0);
      await changes.copySelected([intake], target, IntakeTypeEntity.snack);
      final copies = await repo.getIntakeByDateAndType(
        IntakeTypeEntity.snack,
        target,
        dayStartOffsetHours: 6,
      );
      days.failOnce = true;
      await expectLater(
        changes.deleteSelected(copies, target),
        throwsStateError,
      );
      expect(box.length, 2);
      expect(
        (await dayRepo.getTrackedDay(target))!.caloriesTracked,
        closeTo(40, 1e-9),
      );
      await changes.deleteSelected(copies, target);
      expect(box.values.single.id, intake.id);
    },
  );

  test('same-day cross-meal copy leaves source intact', () async {
    await changes.copySelected([intake], day, IntakeTypeEntity.breakfast);
    expect(
      (await repo.getIntakeByDateAndType(
        IntakeTypeEntity.breakfast,
        day,
        dayStartOffsetHours: 6,
      )).length,
      1,
    );
    expect(
      (await repo.getIntakeById(intake.id))!.type,
      IntakeTypeEntity.dinner,
    );
    expect(
      (await dayRepo.getTrackedDay(day))!.caloriesTracked,
      closeTo(80, 1e-9),
    );
  });
  test(
    'an intake failure after writing the second copy removes the whole batch',
    () async {
      final db = FakeHiveDBProvider(
        intakeBox: box,
        trackedDayBox: Hive.box<TrackedDayDBO>('days'),
      );
      final failing = _FailingIntakes(IntakeDataSource(db));
      final changes = ChangeRecordedIntakeUsecase(failing, days, _Config());
      final target = DateTime(2026, 10, 22);
      await expectLater(
        changes.copySelected([intake, intake], target, IntakeTypeEntity.snack),
        throwsStateError,
      );
      expect(box.values.single.id, intake.id);
      expect(
        (await dayRepo.getTrackedDay(day))!.caloriesTracked,
        closeTo(40, 1e-9),
      );
      expect((await dayRepo.getTrackedDay(target))!.caloriesTracked, 0);
      await changes.copySelected([intake], target, IntakeTypeEntity.snack);
      expect(box.length, 2);
    },
  );
}
