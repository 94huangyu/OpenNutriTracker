import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/personal_food_actions.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

class _Store extends Fake implements PersonalFoodDataSource {
  MealEntity current = MealEntity.empty();
  bool fail = false;
  @override
  bool reviewIsOutdated(MealEntity meal) => false;
  @override
  MealEntity apply(MealEntity meal) => current;
  @override
  Future<MealEntity> setFavorite(MealEntity meal, bool value) async {
    if (fail) throw StateError('disk full');
    return current = current.withPersonalState(
      isFavorite: value,
      reviewSource: current.reviewSource,
      reviewNote: current.reviewNote,
      reviewedAt: current.reviewedAt,
    );
  }

  @override
  Future<MealEntity> review(
    MealEntity meal,
    String source,
    String note, {
    DateTime? now,
  }) async => current = current.withPersonalState(
    isFavorite: current.isFavorite,
    reviewSource: source,
    reviewNote: note,
    reviewedAt: DateTime.utc(2026, 10, 20, 8),
  );
  @override
  Future<MealEntity> clearReview(MealEntity meal) async =>
      current = current.withPersonalState(isFavorite: current.isFavorite);
}

void main() {
  setUpAll(loadCaptureFonts);
  for (final size in [
    (390.0, 1.0, false),
    (320.0, 1.6, false),
    (390.0, 2.0, true),
  ]) {
    testWidgets(
      'favorite / evidence / clear; width=${size.$1}, scale=${size.$2}, dark=${size.$3}',
      (tester) async {
        tester.view.physicalSize = Size(size.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final store = _Store();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(
                size.$3 ? AppPalette.dark : AppPalette.light,
              ),
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
                ).copyWith(textScaler: TextScaler.linear(size.$2)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('食品资料')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PersonalFoodActions(
                    meal: store.current,
                    store: store,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('尚未个人核对'), findsOneWidget);
        await tester.tap(find.bySemanticsIdentifier('food-favorite'));
        await tester.pumpAndSettle();
        expect(store.current.isFavorite, isTrue);
        expect(store.current.isPersonallyReviewed, isFalse);
        await tester.tap(find.bySemanticsIdentifier('food-personal-review'));
        await tester.pumpAndSettle();
        await captureWidget(
          tester,
          key,
          'personal-review-form-${size.$1}-${size.$2}-${size.$3}',
        );
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(store.current.isPersonallyReviewed, isFalse);
        expect(find.text('请填写依据和核对说明'), findsOneWidget);
        final note = find.byType(TextFormField);
        await tester.ensureVisible(note);
        await tester.enterText(note, '包装2026年10月；核对名称、规格和全部已填营养。');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureWidget(
          tester,
          key,
          'personal-review-keyboard-${size.$1}-${size.$2}-${size.$3}',
        );
        await tester.tap(find.text('保存'));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(store.current.isPersonallyReviewed, isTrue);
        expect(store.current.isFavorite, isTrue);
        expect(find.text('我已核对'), findsOneWidget);
        await captureWidget(
          tester,
          key,
          'personal-review-saved-${size.$1}-${size.$2}-${size.$3}',
        );
        await tester.ensureVisible(
          find.bySemanticsIdentifier('food-clear-review'),
        );
        await tester.tap(find.bySemanticsIdentifier('food-clear-review'));
        await tester.pumpAndSettle();
        expect(store.current.isPersonallyReviewed, isFalse);
        expect(store.current.isFavorite, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'failed favorite write shows error and restores actionable state',
    (tester) async {
      final store = _Store()..fail = true;
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
            body: PersonalFoodActions(
              meal: store.current,
              store: store,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('food-favorite'));
      await tester.pumpAndSettle();
      expect(store.current.isFavorite, isFalse);
      expect(find.text('保存失败，仍保留上次已保存的状态，请重试。'), findsOneWidget);
      store.fail = false;
      await tester.tap(find.bySemanticsIdentifier('food-favorite'));
      await tester.pumpAndSettle();
      expect(store.current.isFavorite, isTrue);
    },
  );
}
