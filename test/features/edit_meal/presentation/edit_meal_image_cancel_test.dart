import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/services.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/user_image_picker_tile.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../helpers/personal_food_fixture.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Config extends Fake implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);
}

class _Preferences extends Fake implements ConfigRepository {
  @override
  Future<String?> getCustomMealFormMode() async => 'simple';
}

class _Meals extends Fake implements CustomMealDataSource {
  MealDBO? saved;
  bool fail = false;
  @override
  Future<bool> updateCustomMeal(
    MealDBO meal, {
    String? originalCode,
    String? originalName,
  }) async {
    if (fail) throw StateError('synthetic write failure');
    saved = meal;
    return true;
  }
}

void main() {
  final locator = GetIt.instance;
  // The thumbnail is decoded asynchronously; fixtures must be real images.
  final originalBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
  );
  final incomingBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==',
  );
  late Directory root;
  late File original;
  late File credit;
  late PathProviderPlatform oldPaths;

  late _Meals meals;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ont-photo-cancel-');
    oldPaths = PathProviderPlatform.instance;

    PathProviderPlatform.instance = _Paths(root.path);
    original = File('${root.path}/meal_images/original.webp');
    await original.parent.create();
    await original.writeAsBytes(originalBytes);
    credit = File('${original.path}.credit.json');
    await credit.writeAsString('{"name":"synthetic author"}');
    final incoming = File('${root.path}/incoming.bin');
    await incoming.writeAsBytes(incomingBytes);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (call) async {
            expect(call.method, 'pickImage');
            return incoming.path;
          },
        );
    meals = _Meals();
    locator.registerFactory<EditMealBloc>(
      () => EditMealBloc(_Config(), meals, _Preferences()),
    );
  });
  tearDown(() async {
    await locator.reset();
    PathProviderPlatform.instance = oldPaths;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          null,
        );
    await root.delete(recursive: true);
  });
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final meal = MealEntity.fromMealDBO(
      MealDBO.fromJson({
        ...jsonDecode(
              jsonEncode(
                MealDBO.fromMealEntity(
                  food(code: 'original', source: MealSourceEntity.custom),
                ).toJson(),
              ),
            )
            as Map<String, dynamic>,
        'localImagePath': 'meal_images/original.webp',
      }),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<EnergyUnitProvider>(
        create: (_) => EnergyUnitProvider(),
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.supportedLocales,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('list')),
          ),
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('list')),
            ),
            MaterialPageRoute<void>(
              settings: RouteSettings(
                arguments: EditMealScreenArguments(
                  DateTime(2026, 10, 21),
                  meal,
                  IntakeTypeEntity.lunch,
                  false,
                  editOnly: true,
                ),
              ),
              builder: (_) => const EditMealScreen(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  UserImagePickerTile tile(WidgetTester tester) =>
      tester.widget<UserImagePickerTile>(find.byType(UserImagePickerTile));
  Future<void> verifyOriginal(WidgetTester tester) async {
    await tester.runAsync(() async {
      expect(await original.readAsBytes(), originalBytes);
      expect(await credit.readAsString(), '{"name":"synthetic author"}');
    });
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }

  testWidgets('remove then cancel keeps saved photo and credit', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(tile(tester).onRemove);
    await tester.pumpAndSettle();
    await verifyOriginal(tester);
    await close(tester);
    await verifyOriginal(tester);
    expect(meals.saved, isNull);
  });
  for (final result in ['cancel', 'failed save', 'saved']) {
    testWidgets('replace then $result preserves original snapshot bytes', (
      tester,
    ) async {
      await pump(tester);
      await tester.runAsync(tile(tester).onPickFromGallery);
      await tester.pumpAndSettle();
      final draft = tile(tester).imagePath!;
      expect(draft, isNot('meal_images/original.webp'));
      await verifyOriginal(tester);
      if (result != 'cancel') {
        meals.fail = result == 'failed save';
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        if (result == 'saved') expect(meals.saved!.localImagePath, draft);
      }
      await close(tester);
      await verifyOriginal(tester);
      await tester.runAsync(() async {
        expect(await File('${root.path}/$draft').exists(), result == 'saved');
      });
    });
  }
}
