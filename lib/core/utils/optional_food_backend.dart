import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A missing optional reference database must not block local diary startup.
bool hasFoodBackendConfiguration(String url, String key) {
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      key.trim().isNotEmpty &&
      key.trim() != 'ANON_KEY';
}

Future<void> registerOptionalFoodBackend(
  GetIt services, {
  required String url,
  required String key,
}) async {
  if (!hasFoodBackendConfiguration(url, key)) return;
  await Supabase.initialize(
    url: url.trim(),
    publishableKey: key.trim(),
    // The app logger already handles Supabase records.
    debug: false,
  );
  services.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );
}
