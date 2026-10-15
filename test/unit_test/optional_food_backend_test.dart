import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/optional_food_backend.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_food_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => locator.reset());

  test(
    'missing, placeholder or invalid config skips backend initialization',
    () async {
      final services = GetIt.asNewInstance();
      for (final config in [
        ('', ''),
        ('PROJECT_URL', 'ANON_KEY'),
        ('https://example.supabase.co', ''),
        ('https://example.supabase.co', 'ANON_KEY'),
        ('file:///tmp/backend', 'key'),
        ('https://', 'key'),
      ]) {
        expect(hasFoodBackendConfiguration(config.$1, config.$2), isFalse);
        await registerOptionalFoodBackend(
          services,
          url: config.$1,
          key: config.$2,
        );
        expect(services.isRegistered<SupabaseClient>(), isFalse);
      }
      await services.reset();
    },
  );

  test('configured hosted and self-hosted URLs retain backend support', () {
    expect(
      hasFoodBackendConfiguration('https://example.supabase.co', 'public-key'),
      isTrue,
    );
    expect(
      hasFoodBackendConfiguration('http://localhost:54321', 'public-key'),
      isTrue,
    );
  });

  test(
    'unconfigured reference search returns locally without client or config access',
    () async {
      expect(locator.isRegistered<SupabaseClient>(), isFalse);
      final source = SpFoodDataSource();
      expect(await source.fetchSearchWordResults('牛奶'), isEmpty);
      expect(
        await source.fetchSearchWordResults('牛奶', forResolution: true),
        isEmpty,
      );
    },
  );
}
