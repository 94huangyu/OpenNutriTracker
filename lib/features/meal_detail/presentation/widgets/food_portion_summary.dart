import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/utils/energy_display.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Nullable values keep unknown nutrition distinct from a known zero.
class FoodPortionSummary extends StatelessWidget {
  final String caption;
  final double? kcal;
  final double? carbs;
  final double? protein;
  final double? fat;

  const FoodPortionSummary({
    super.key,
    required this.caption,
    required this.kcal,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final label = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget macro(String name, double? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(name, style: label)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value == null ? '—' : '${value.toStringAsFixed(1)} g',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
    final energy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: label),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: kcal == null
                ? '—'
                : EnergyDisplay.convert(context, kcal!).round().toString(),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: ' ${EnergyDisplay.unitLabel(context)}',
                style: label,
              ),
            ],
          ),
        ),
      ],
    );
    final macros = Column(
      children: [
        macro(s.carbsLabel, carbs),
        macro(s.proteinLabel, protein),
        macro(s.fatLabel, fat),
      ],
    );
    return AppCard(
      shadowed: false,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [energy, const SizedBox(height: 12), macros],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: energy),
              const SizedBox(width: 20),
              Expanded(child: macros),
            ],
          );
        },
      ),
    );
  }
}
