import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

/// Serialises undo/copy with deletion and derives totals from persisted records.
class ChangeRecordedIntakeUsecase {
  final IntakeRepository _intakes;
  final AddTrackedDayUsecase _days;
  final GetConfigUsecase _config;
  Future<void> _pending = Future.value();

  ChangeRecordedIntakeUsecase(this._intakes, this._days, this._config);

  Future<void> delete(IntakeEntity intake, DateTime day) =>
      _queue(() => _change(intake, day, remove: true));

  Future<void> restore(IntakeEntity intake, DateTime day) =>
      _queue(() => _change(intake, day, remove: false));

  Future<void> repeat(
    IntakeEntity intake,
    DateTime day,
    double amount,
    String unit,
  ) {
    final copy = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: unit,
      amount: amount,
      type: intake.type,
      meal: intake.meal,
      dateTime: intake.dateTime,
    );
    return _queue(() => _change(copy, day, remove: false));
  }

  Future<void> _queue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _change(
    IntakeEntity intake,
    DateTime day, {
    required bool remove,
  }) async {
    final previous = await _intakes.getIntakeById(intake.id);
    // Undo is safe to retry; it cannot overwrite or add the same record twice.
    if (remove ? previous == null : previous != null) return;
    if (remove) {
      await _intakes.deleteIntake(previous!);
    } else {
      if (!intake.amount.isFinite || intake.amount <= 0) {
        throw ArgumentError.value(intake.amount, 'amount');
      }
      await _intakes.addIntake(intake);
    }
    try {
      await _reconcile(day);
    } catch (_) {
      // Hive has no cross-box transaction: compensate before reporting failure.
      if (previous == null) {
        await _intakes.deleteIntake(intake);
      } else {
        await _intakes.addIntake(previous);
      }
      await _reconcile(day);
      rethrow;
    }
  }

  Future<void> _reconcile(DateTime day) async {
    final config = await _config.getConfig();
    final groups = await Future.wait([
      for (final type in IntakeTypeEntity.values)
        _intakes.getIntakeByDateAndType(
          type,
          day,
          dayStartOffsetHours: config.dayStartOffsetHours,
          dayStartOffsetMinutes: config.dayStartOffsetMinutes,
        ),
    ]);
    if (!await _days.hasTrackedDay(day)) {
      await _days.addNewTrackedDay(day, 0, 0, 0, 0);
    }
    final all = groups.expand((group) => group);
    double sum(double Function(IntakeEntity) read) =>
        all.fold(0, (total, intake) => total + read(intake));
    await _days.reconcileDayTracked(
      day,
      sum((i) => i.totalKcal),
      sum((i) => i.totalCarbsGram),
      sum((i) => i.totalFatsGram),
      sum((i) => i.totalProteinsGram),
    );
  }
}
