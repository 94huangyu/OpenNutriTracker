import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_food_data_source.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/food_sources_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../helpers/widget_capture.dart';

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async => const ConfigEntity(
    false,
    false,
    false,
    AppThemeEntity.system,
    foodSourceToggles: {'bls': true},
  );
}

class _Backend extends SpFoodDataSource {
  final bool configured;
  _Backend(this.configured);
  @override
  bool get isConfigured => configured;
}

void main() {
  setUpAll(loadCaptureFonts);
  for (final configured in [false, true]) {
    testWidgets('source availability is explicit; configured=$configured', (
      tester,
    ) async {
      final locator = GetIt.instance;
      locator.registerSingleton<GetConfigUsecase>(_Config());
      locator.registerSingleton<SpFoodDataSource>(_Backend(configured));
      addTearDown(locator.reset);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(AppPalette.light),
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
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const FoodSourcesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches.first.value, isTrue); // OFF needs no backend account.
      if (!configured) {
        expect(find.textContaining('此版本未接入'), findsOneWidget);
        expect(
          switches.skip(1).every((s) => s.onChanged == null && !s.value),
          isTrue,
        );
      } else {
        expect(find.textContaining('此版本未接入'), findsNothing);
        expect(switches.skip(1).every((s) => s.onChanged != null), isTrue);
      }
      expect(tester.takeException(), isNull);
      await captureWidget(tester, capture, 'source-settings-$configured');
    });
  }
}
