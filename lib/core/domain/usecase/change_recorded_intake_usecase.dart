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
      _queue(() => _changeSelected([intake], day, remove: true));

  Future<void> restore(IntakeEntity intake, DateTime day) =>
      _queue(() => _changeSelected([intake], day, remove: false));

  Future<void> deleteSelected(List<IntakeEntity> items, DateTime day) =>
      _queue(() => _changeSelected(items, day, remove: true));

  Future<void> copySelected(
    List<IntakeEntity> items,
    DateTime day,
    IntakeTypeEntity type,
  ) {
    final targetDay = DateTime(day.year, day.month, day.day);
    final copies = [
      for (final item in items)
        IntakeEntity(
          id: IdGenerator.getUniqueID(),
          unit: item.unit,
          amount: item.amount,
          type: type,
          meal: item.meal,
          dateTime: targetDay,
        ),
    ];
    return _queue(() => _changeSelected(copies, targetDay, remove: false));
  }

  Future<void> _changeSelected(
    List<IntakeEntity> items,
    DateTime day, {
    required bool remove,
  }) async {
    final planned = <String, IntakeEntity>{};
    for (final item in items) {
      final previous = await _intakes.getIntakeById(item.id);
      if (remove ? previous == null : previous != null) continue;
      if (!remove && (!item.amount.isFinite || item.amount <= 0)) {
        throw ArgumentError.value(item.amount, 'amount');
      }
      planned[item.id] = remove ? previous! : item;
    }
    if (planned.isEmpty) return;
    try {
      for (final item in planned.values) {
        if (remove) {
          await _intakes.deleteIntake(item);
        } else {
          await _intakes.addIntake(item);
        }
      }
      await _reconcile(day);
    } catch (_) {
      // Hive has no cross-box transaction; restore the whole plan before retry.
      for (final item in planned.values.toList().reversed) {
        if (remove) {
          await _intakes.addIntake(item);
        } else {
          await _intakes.deleteIntake(item);
        }
      }
      await _reconcile(day);
      rethrow;
    }
  }

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
    return _queue(() => _changeSelected([copy], day, remove: false));
  }

  Future<void> _queue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
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
