import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  for (final entry in [
    (null, null, '我的食品', false),
    (
      'https://world.openfoodfacts.org/product/123',
      null,
      '原始参考：world.openfoodfacts.org',
      true,
    ),
    ('file:///private/food', 'bls', '原始参考：', false),
  ]) {
    testWidgets('personal source attribution with safe reference $entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: MealInfoButton(
              url: entry.$1,
              source: MealSourceEntity.custom,
              backendSource: entry.$2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.$3), findsOneWidget);
      expect(find.textContaining('已核验'), findsNothing);
      if (entry.$1 != null) {
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed != null,
          entry.$4,
        );
      }
    });
  }
}
