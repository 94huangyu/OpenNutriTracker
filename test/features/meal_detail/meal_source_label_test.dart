import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  testWidgets('OFF correction without URL shows source and original item id', (
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
            url: null,
            source: MealSourceEntity.custom,
            originalSource: 'off',
            originalCode: '00012345',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Food Facts · 00012345'), findsOneWidget);
    expect(find.textContaining('我的食品'), findsOneWidget);
    expect(find.textContaining('已核验'), findsNothing);
  });
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
          tester
                  .widget<TextButton>(
                    find.descendant(
                      of: find.byWidgetPredicate(
                        (w) =>
                            w is Semantics &&
                            w.properties.identifier == 'meal-info-source',
                      ),
                      matching: find.byType(TextButton),
                    ),
                  )
                  .onPressed !=
              null,
          entry.$4,
        );
      }
    });
  }

  for (final source in [MealSourceEntity.off, MealSourceEntity.custom]) {
    testWidgets(
      'nutrition and source details stay available on demand $source',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealInfoButton(url: null, source: source),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('4/4/9'), findsNothing);
        expect(find.textContaining('无法保证'), findsNothing);
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.identifier == 'meal-nutrition-source-info',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('4/4/9'), findsOneWidget);
        expect(
          find.textContaining('无法保证'),
          source == MealSourceEntity.off ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }
}
