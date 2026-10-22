import 'package:opennutritracker/core/data/dbo/profile_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/switch_profile_usecase.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/profile_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/profile_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_profile_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locale_provider.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/recording/presentation/recording_settings.dart';
import 'package:opennutritracker/features/recording/presentation/recording_trends_page.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/full_backup_screen.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import '../../helpers/full_backup_fixture.dart';
import '../../helpers/widget_capture.dart';

class _Secure extends Fake implements SecureAppStorageProvider {
  String? active;
  @override
  Future<void> setActiveProfileId(String id) async {
    active = id;
  }
}

class _FailThemeRepository extends ConfigRepository {
  _FailThemeRepository(super.source);
  @override
  Future<void> setConfigAppTheme(AppThemeEntity value) async {
    throw StateError('Injected preference write failure');
  }
}

class _Changes extends Fake implements CalendarDayBloc {
  int refreshes = 0;
  @override
  void add(CalendarDayEvent event) {
    refreshes++;
  }
}

Finder id(String value) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.identifier == value,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FullBackupFixture fixture;
  late Uint8List bytes;
  final getIt = GetIt.instance;
  final capture = GlobalKey();
  var fixtureClosed = false;
  final changes = _Changes();
  setUpAll(loadCaptureFonts);
  setUp(() async {
    fixtureClosed = false;
    fixture = await FullBackupFixture.open();
    bytes = await fixture.service.export();
    final config = ConfigRepository(ConfigDataSource(fixture.db));
    final profiles = ProfileRepository(ProfileDataSource(fixture.db));
    getIt.registerSingleton<HiveDBProvider>(fixture.db);
    getIt.registerSingleton<ConfigRepository>(config);
    getIt.registerSingleton<ProfileRepository>(profiles);
    getIt.registerSingleton<UpdateProfileUsecase>(
      UpdateProfileUsecase(profiles),
    );
    getIt.registerSingleton<GetConfigUsecase>(GetConfigUsecase(config));
    getIt.registerSingleton<IntakeRepository>(
      IntakeRepository(IntakeDataSource(fixture.db)),
    );
    getIt.registerSingleton<CalendarDayBloc>(changes);
    DayBoundaryCalc.clock = () => DateTime(2026, 10, 20, 12);
  });
  tearDown(() async {
    await getIt.reset();
    if (!fixtureClosed) await fixture.close();
    DayBoundaryCalc.clock = DateTime.now;
  });

  // Flush real I/O and Hive's fake-zone microtasks before testWidgets exits
  // its inTest zone. Pumping from a normal tearDown is too late.
  void testScreen(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        var closed = false;
        final closing = fixture.close().whenComplete(() => closed = true);
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pump();
        }
        await closing;
        fixtureClosed = true;
      }
    });
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 20));
      final loading = find.byWidgetPredicate((w) => w is PopScope && !w.canPop);
      if (loading.evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double width = 390,
    double scale = 1,
    bool dark = false,
    String language = 'zh',
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => EnergyUnitProvider(usesKilojoules: true),
            ),
            ChangeNotifierProvider(
              create: (_) => ThemeModeProvider(
                appTheme: dark ? AppThemeEntity.dark : AppThemeEntity.light,
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => LocaleProvider(locale: Locale(language)),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark ? AppPalette.dark : AppPalette.light),
            locale: Locale(language),
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
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    );
    await settleIo(tester);
  }

  Future<void> reveal(WidgetTester tester, String identifier) async {
    if (id(identifier).evaluate().isEmpty) {
      tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        id(identifier),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(id(identifier));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String identifier) async {
    await reveal(tester, identifier);
    await tester.runAsync(() => tester.tap(id(identifier)));
    await settleIo(tester);
  }

  testScreen(
    'full export uses real ZIP; preview/cancel is read-only; explicit restore refreshes',
    (tester) async {
      Uint8List? saved;
      var restored = 0;
      await tester.runAsync(() => fixture.db.intakeBox.clear());
      await pump(
        tester,
        FullBackupScreen(
          service: fixture.service,
          pickBackup: () async => bytes,
          saveBackup: (b) async {
            saved = b;
            return true;
          },
          onRestored: () async {
            restored++;
          },
        ),
      );
      await tap(tester, 'backup-export-full');
      expect(
        ZipDecoder().decodeBytes(saved!).findFile('manifest.json'),
        isNotNull,
      );
      await tap(tester, 'backup-pick-restore');
      expect(fixture.db.intakeBox.isEmpty, true);
      await tap(tester, 'backup-cancel-preview');
      expect(fixture.db.intakeBox.isEmpty, true);
      await tap(tester, 'backup-pick-restore');
      await reveal(tester, 'backup-conflict-policy');
      await tester.tap(id('backup-conflict-policy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('冲突时使用备份').last);
      await tester.pumpAndSettle();
      await tap(tester, 'backup-confirm-restore');
      expect(fixture.db.intakeBox.length, 1);
      expect(restored, 1);
      expect(id('backup-confirm-restore'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, 1800));
      await tester.pumpAndSettle();
      await captureWidget(tester, capture, 'm4-backup-restored');
    },
  );

  for (final layout in [
    (320.0, 1.6, false, 'zh'),
    (390.0, 2.0, true, 'zh'),
    (320.0, 1.6, false, 'en'),
  ]) {
    final suffix = '${layout.$1}-${layout.$2}-${layout.$3}-${layout.$4}';
    testScreen('backup preview layout $suffix', (tester) async {
      await pump(
        tester,
        FullBackupScreen(
          service: fixture.service,
          pickBackup: () async => bytes,
        ),
        width: layout.$1,
        scale: layout.$2,
        dark: layout.$3,
        language: layout.$4,
      );
      await captureWidget(tester, capture, 'm4-backup-top-$suffix');
      await tap(tester, 'backup-pick-restore');
      await reveal(tester, 'backup-conflict-policy');
      await captureWidget(tester, capture, 'm4-backup-conflicts-$suffix');
      await tap(tester, 'backup-cancel-preview');
      expect(tester.takeException(), isNull);
    });
    testScreen('recording settings layout $suffix', (tester) async {
      await pump(
        tester,
        const RecordingSettings(),
        width: layout.$1,
        scale: layout.$2,
        dark: layout.$3,
        language: layout.$4,
      );
      expect(find.text('BMI'), findsNothing);
      await captureWidget(tester, capture, 'm4-settings-top-$suffix');
      await reveal(tester, 'recording-settings-sources');
      await captureWidget(tester, capture, 'm4-settings-bottom-$suffix');
      expect(tester.takeException(), isNull);
    });
    testScreen('intake-only trends layout $suffix', (tester) async {
      await pump(
        tester,
        const RecordingTrendsPage(),
        width: layout.$1,
        scale: layout.$2,
        dark: layout.$3,
        language: layout.$4,
      );
      await captureWidget(tester, capture, 'm4-trends-top-$suffix');
      await tester.ensureVisible(id('trends-nutrient'));
      await tester.tap(id('trends-nutrient'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(layout.$4 == 'zh' ? '钠' : 'sodium').last,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(layout.$4 == 'zh' ? '钠' : 'sodium').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await captureWidget(tester, capture, 'm4-trends-sodium-$suffix');
      expect(tester.takeException(), isNull);
    });
  }

  testScreen('invalid ZIP and legacy partial warning do not write', (
    tester,
  ) async {
    var selected = Uint8List.fromList([1, 2, 3]);
    await pump(
      tester,
      FullBackupScreen(
        service: fixture.service,
        pickBackup: () async => selected,
      ),
    );
    await tap(tester, 'backup-pick-restore');
    expect(find.textContaining('文件损坏'), findsOneWidget);
    expect(fixture.db.intakeBox.length, 1);
    await captureWidget(tester, capture, 'm4-backup-invalid');
    final archive = Archive();
    for (final name in [
      'user_intake.json',
      'user_activity.json',
      'user_tracked_day.json',
    ]) {
      final content = utf8.encode('[]');
      archive.addFile(ArchiveFile(name, content.length, content));
    }
    selected = Uint8List.fromList(ZipEncoder().encode(archive));
    await tap(tester, 'backup-pick-restore');
    final warning = find.textContaining('这是旧版部分备份');
    await tester.ensureVisible(warning);
    expect(warning, findsOneWidget);
    await captureWidget(tester, capture, 'm4-backup-legacy-preview');
    expect(fixture.db.intakeBox.length, 1);
  });

  testScreen('unknown nutrient days and empty period are shown explicitly', (
    tester,
  ) async {
    await tester.runAsync(
      () => fixture.db.intakeBox.put(
        1,
        IntakeDBO(
          id: 'unknown',
          amount: 20,
          unit: 'g',
          type: IntakeTypeDBO.lunch,
          dateTime: DateTime(2026, 10, 20),
          meal: MealDBO.fromMealEntity(MealEntity.empty()),
        ),
      ),
    );
    await pump(tester, const RecordingTrendsPage());
    expect(find.textContaining('仅已知部分'), findsWidgets);
    await captureWidget(tester, capture, 'm4-trends-partial');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => fixture.db.intakeBox.clear());
    await pump(tester, const RecordingTrendsPage());
    expect(find.text('此时段暂无摄入记录'), findsOneWidget);
    await captureWidget(tester, capture, 'm4-trends-empty');
  });
  testScreen(
    'units, theme and profile rename persist without reading body data',
    (tester) async {
      await pump(tester, const RecordingSettings());
      await tap(tester, 'recording-settings-kj');
      expect(fixture.db.appConfigBox.values.single.usesKilojoules, false);
      await reveal(tester, 'recording-settings-theme');
      await tester.tap(id('recording-settings-theme'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('深色').last));
      await settleIo(tester);
      expect(
        fixture.db.appConfigBox.values.single.selectedAppTheme.name,
        'dark',
      );
      await tap(tester, 'recording-profile-rename');
      final input = find.descendant(
        of: id('recording-profile-name'),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, '本机饮食日记');
      await tester.runAsync(() => tester.tap(find.text('保存修改')));
      await settleIo(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await settleIo(tester);
      expect(fixture.db.profileBox.get('p')!.name, '本机饮食日记');
      expect(fixture.db.userBox.values.single.heightCM, 165);
      expect(fixture.db.userActivityBox.values.single.id, 'historic-activity');
    },
  );

  testScreen('switch to a restored local profile needs no body information', (
    tester,
  ) async {
    final secure = _Secure();
    getIt.registerSingleton<SwitchProfileUsecase>(
      SwitchProfileUsecase(fixture.db, secure, ConfigDataSource(fixture.db)),
    );
    await tester.runAsync(
      () => fixture.db.profileBox.put(
        'second',
        ProfileDBO(
          id: 'second',
          name: '第二份资料',
          createdAt: DateTime(2026, 10, 21),
          boxSuffix: 'second',
        ),
      ),
    );
    await pump(tester, const RecordingSettings());
    await tap(tester, 'recording-profile-select');
    await tester.runAsync(() => tester.tap(find.text('第二份资料').last));
    await settleIo(tester);
    expect(fixture.db.activeProfileId, 'second');
    expect(secure.active, 'second');
    expect(fixture.db.userBox.isEmpty, true);
    expect(fixture.db.intakeBox.isEmpty, true);
    expect(fixture.db.personalFoodBox.length, 1);
    expect(find.text('BMI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testScreen('post-commit display failure reports committed data accurately', (
    tester,
  ) async {
    await tester.runAsync(() => fixture.db.intakeBox.clear());
    await pump(
      tester,
      FullBackupScreen(
        service: fixture.service,
        pickBackup: () async => bytes,
        onRestored: () async {
          throw StateError('UI refresh failed');
        },
      ),
    );
    await tap(tester, 'backup-pick-restore');
    await tap(tester, 'backup-confirm-restore');
    expect(fixture.db.intakeBox.length, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 2500));
    await tester.pumpAndSettle();
    expect(find.textContaining('数据已恢复，但页面刷新未完成'), findsOneWidget);
  });
  testScreen('failed preference save resets the visible selection', (
    tester,
  ) async {
    await getIt.unregister<ConfigRepository>();
    getIt.registerSingleton<ConfigRepository>(
      _FailThemeRepository(ConfigDataSource(fixture.db)),
    );
    await pump(tester, const RecordingSettings());
    await reveal(tester, 'recording-settings-theme');
    await tester.tap(id('recording-settings-theme'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('深色').last));
    await settleIo(tester);
    final field = find.descendant(
      of: id('recording-settings-theme'),
      matching: find.byType(DropdownButtonFormField<AppThemeEntity>),
    );
    expect(
      tester.state<FormFieldState<AppThemeEntity>>(field).value,
      AppThemeEntity.light,
    );
    expect(
      fixture.db.appConfigBox.values.single.selectedAppTheme.name,
      'system',
    );
  });
}
