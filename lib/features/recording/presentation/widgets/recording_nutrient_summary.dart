import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/generated/l10n.dart';

class RecordingNutrientSummary extends StatelessWidget {
  final List<IntakeEntity> items;
  const RecordingNutrientSummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final label = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.6,
    );
    double sum(double Function(IntakeEntity) read) =>
        items.fold(0, (total, item) => total + read(item));
    Widget macro(String name, double value) {
      final number = Text(
        '${value.toStringAsFixed(1)} g',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
      if (MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: label),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: number,
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(name, style: label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: number,
              ),
            ),
          ),
        ],
      );
    }

    final kcal = EnergyDisplay.convert(
      context,
      sum((i) => i.totalKcal),
    ).round();
    final unit = EnergyDisplay.unitLabel(context);
    return AppCard(
      shadowed: false,
      borderRadius: 18,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.recordingConsumed, style: label),
                const SizedBox(height: 8),
                Semantics(
                  label: '$kcal $unit',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: '$kcal',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [TextSpan(text: ' $unit', style: label)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                macro(s.carbsLabel, sum((i) => i.totalCarbsGram)),
                const SizedBox(height: 8),
                macro(s.proteinLabel, sum((i) => i.totalProteinsGram)),
                const SizedBox(height: 8),
                macro(s.fatLabel, sum((i) => i.totalFatsGram)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
