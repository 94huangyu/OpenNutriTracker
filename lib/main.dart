import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/l10n/app_locales.dart';
import 'package:opennutritracker/core/presentation/main_screen.dart';
import 'package:opennutritracker/core/presentation/splash_screen.dart';
import 'package:opennutritracker/core/presentation/storage_recovery_app.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/core/utils/app_const.dart';
import 'package:opennutritracker/core/utils/app_locale_service.dart';
import 'package:opennutritracker/core/utils/app_locale_sync.dart';
import 'package:opennutritracker/core/utils/hive_storage_integrity_exception.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/logger_config.dart';
import 'package:opennutritracker/core/utils/notification_service.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locale_provider.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/activity_detail/activity_detail_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/screens/bulk_add_screen.dart';
import 'package:opennutritracker/features/add_activity/presentation/add_activity_screen.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/fasting/presentation/fasting_screen.dart';
import 'package:opennutritracker/features/profile/presentation/screens/manage_profiles_screen.dart';
import 'package:opennutritracker/features/profile/presentation/weight_history_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/import_recipe_scanner_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_builder_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipes_page.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_activity_scanner_screen.dart';
import 'package:opennutritracker/features/home/presentation/screens/import_meal_scanner_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/accent_colour_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/health_sync_screen.dart';
import 'package:opennutritracker/features/recording/presentation/recording_settings.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

/// The locales the app resolves against: gen-l10n's list narrowed to the
/// shipped languages, computed once (WidgetsApp compares the list by
/// identity, so a fresh list per build would re-resolve on every rebuild).
final _appLocales = appLocales(S.supportedLocales);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerConfig.intiLogger();
  await _bootstrapApp();
}

Future<void> _bootstrapApp() async {
  final log = Logger('main');
  try {
    await initLocator();
  } on HiveStorageIntegrityException catch (error, stackTrace) {
    // Consent (and thus Sentry) lives in the encrypted Config Hive box, so it
    // cannot be read on this path. Keep diagnostics local and preserve the
    // database files while giving the user a safe, retryable recovery screen.
    log.severe(
      'Local database integrity failure during bootstrap '
      '(code=${error.code}). Not reporting to Sentry before consent.',
      error,
      stackTrace,
    );
    runApp(StorageRecoveryApp(errorCode: error.code, onRetry: _bootstrapApp));
    return;
  }

  // Drop cached remote-search results that haven't been touched in 90
  // days. Done once per app start; no need to schedule a recurring task.
  unawaited(
    locator<RemoteSearchCacheDataSource>().pruneStale(const Duration(days: 90)),
  );

  final isUserInitialized = await locator<UserDataSource>().hasUserData();
  final configRepo = locator<ConfigRepository>();

  final config = await configRepo.getConfig();
  // Android's own per-app language picker and ours are two doors into the
  // same setting, so ask the system what it holds before trusting what we
  // saved. See [reconcileAppLocale] for which side wins and why.
  final localeCode = await reconcileAppLocale(
    savedLocaleCode: await configRepo.getSelectedLocale(),
    systemLocaleTag: await AppLocaleService.getApplicationLocale(),
    supportedLocales: _appLocales,
    persistSelectedLocale: configRepo.setSelectedLocale,
    pushToSystem: AppLocaleService.setApplicationLocale,
  );
  final savedLocale = localeCode != null ? Locale(localeCode) : null;

  // #312: Restore scheduled notifications after app start / device reboot.
  // Look up the user's localized strings first — there's no widget tree yet,
  // so S is driven directly off the saved (or device) locale, resolved against
  // the supported locales because lookupS throws on unsupported ones. Android
  // re-applies the channel name/description on every (re)registration, and
  // they surface in the OS settings, so this keeps them in the user's
  // language instead of reverting to English on each launch.
  if (config.notificationsEnabled) {
    final s = lookupS(
      basicLocaleListResolution([
        savedLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
      ], _appLocales),
    );
    final notificationService = locator<NotificationService>();
    await notificationService.initialize();
    await notificationService.scheduleDailyReminder(
      hour: config.notificationHour,
      minute: config.notificationMinute,
      title: s.notificationsDailyReminderTitle,
      body: s.notificationsDailyReminderBody,
      channelName: s.notificationsDailyReminderChannelName,
      channelDescription: s.notificationsDailyReminderChannelDescription,
    );
  }
  final savedAppTheme = await configRepo.getConfigAppTheme();
  final savedUsesKilojoules = config.usesKilojoules;
  final savedUseMaterialYou = config.useMaterialYou;
  final savedAccentColor = config.accentColor;

  log.info('Starting intake recording app without telemetry ...');
  runAppWithChangeNotifiers(
    isUserInitialized,
    savedAppTheme,
    savedLocale,
    savedUsesKilojoules,
    savedUseMaterialYou,
    savedAccentColor,
  );
}

void runAppWithChangeNotifiers(
  bool userInitialized,
  AppThemeEntity savedAppTheme,
  Locale? savedLocale,
  bool savedUsesKilojoules,
  bool savedUseMaterialYou,
  int? savedAccentColor,
) => runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ThemeModeProvider(
          appTheme: savedAppTheme,
          useMaterialYou: savedUseMaterialYou,
          accentColor: savedAccentColor,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(locale: savedLocale),
      ),
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(usesKilojoules: savedUsesKilojoules),
      ),
    ],
    child: OpenNutriTrackerApp(userInitialized: userInitialized),
  ),
);

class OpenNutriTrackerApp extends StatefulWidget {
  final bool userInitialized;

  const OpenNutriTrackerApp({super.key, required this.userInitialized});

  @override
  State<OpenNutriTrackerApp> createState() => _OpenNutriTrackerAppState();
}

class _OpenNutriTrackerAppState extends State<OpenNutriTrackerApp>
    with WidgetsBindingObserver {
  Timer? _systemUiRestoreTimer;
  bool _keyboardVisible = false;
  bool _keyboardUsed = false;
  static const _systemUiChannel = MethodChannel('com.opennutritracker/system_ui');
  late final _systemUiReturnObserver = _SystemUiReturnObserver(() {
    if (_keyboardUsed && !_keyboardVisible) {
      _scheduleSystemUiRestore(returnedHome: true);
    }
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _systemUiRestoreTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final visible = View.of(context).viewInsets.bottom > 0;
    if (visible == _keyboardVisible) return;
    _keyboardVisible = visible;
    _systemUiRestoreTimer?.cancel();
    if (visible) {
      _keyboardUsed = true;
    } else {
      _scheduleSystemUiRestore();
    }
  }

  void _scheduleSystemUiRestore({bool returnedHome = false}) {
    _systemUiRestoreTimer?.cancel();
    _systemUiRestoreTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted || _keyboardVisible) return;
      if (returnedHome) _keyboardUsed = false;
      unawaited(_refreshStatusIcons());
    });
  }

  Future<void> _refreshStatusIcons() async {
    try {
      // Keep Flutter's cached route style unchanged while the native request
      // changes for long enough to reach SystemUI. Then reapply the current
      // route, including any theme/navigation change made during this delay.
      if (await _systemUiChannel.invokeMethod<bool>('prepareStatusBarRefresh') ==
          true) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await SystemChrome.restoreSystemUIOverlays();
      }
    } on PlatformException catch (error) {
      Logger('SystemUI').warning('Could not refresh status icons', error);
    } on MissingPluginException catch (error) {
      Logger('SystemUI').warning('Status icon refresh unavailable', error);
    }
  }

  /// Android delivers this when someone changes the app's language from
  /// Settings -> Apps -> OpenNutriTracker -> Language while the app is alive.
  /// `MaterialApp.locale` is pinned to our own saved choice, so without
  /// adopting the new value here that picker would appear to do nothing.
  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    unawaited(_adoptSystemLocale());
  }

  Future<void> _adoptSystemLocale() async {
    final systemCode = supportedLanguageCode(
      await AppLocaleService.getApplicationLocale(),
      _appLocales,
    );
    if (systemCode == null || !mounted) return;

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    if (localeProvider.locale?.languageCode == systemCode) return;

    localeProvider.updateLocale(Locale(systemCode));
    await locator<ConfigRepository>().setSelectedLocale(systemCode);
  }

  @override
  Widget build(BuildContext context) {
    return _buildMaterialApp(context, AppPalette.light, AppPalette.dark);
  }

  Widget _buildMaterialApp(
    BuildContext context,
    AppPalette lightPalette,
    AppPalette darkPalette,
  ) {
    return MaterialApp(
      navigatorObservers: [_systemUiReturnObserver],
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: child ?? const SizedBox.shrink(),
      ),
      onGenerateTitle: (context) => AppConst.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(lightPalette),
      darkTheme: buildAppTheme(darkPalette),
      themeMode: Provider.of<ThemeModeProvider>(context).themeMode,
      locale: Provider.of<LocaleProvider>(context).locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: _appLocales,
      initialRoute: NavigationOptions.splashRoute,
      routes: {
        NavigationOptions.splashRoute: (context) =>
            SplashScreen(userInitialized: widget.userInitialized),
        NavigationOptions.mainRoute: (context) => const MainScreen(),
        NavigationOptions.onboardingRoute: (context) => const MainScreen(),
        NavigationOptions.settingsRoute: (context) => const RecordingSettings(),
        NavigationOptions.accentColourRoute: (context) =>
            const AccentColourScreen(),
        NavigationOptions.healthSyncRoute: (context) => const HealthSyncScreen(),
        NavigationOptions.addMealRoute: (context) => const AddMealScreen(),
        NavigationOptions.bulkAddRoute: (context) => const BulkAddScreen(),
        NavigationOptions.scannerRoute: (context) => const ScannerScreen(),
        NavigationOptions.mealDetailRoute: (context) =>
            const MealDetailScreen(),
        NavigationOptions.editMealRoute: (context) => const EditMealScreen(),
        NavigationOptions.addActivityRoute: (context) =>
            const AddActivityScreen(),
        NavigationOptions.activityDetailRoute: (context) =>
            const ActivityDetailScreen(),
        NavigationOptions.imageFullScreenRoute: (context) =>
            const ImageFullScreen(),
        NavigationOptions.importMealScannerRoute: (context) =>
            const ImportMealScannerScreen(),
        NavigationOptions.importActivityScannerRoute: (context) =>
            const ImportActivityScannerScreen(),
        NavigationOptions.recipesRoute: (context) => const RecipesPage(),
        NavigationOptions.recipeBuilderRoute: (context) =>
            const RecipeBuilderScreen(),
        NavigationOptions.recipeDetailRoute: (context) =>
            const RecipeDetailScreen(),
        NavigationOptions.importRecipeScannerRoute: (context) =>
            const ImportRecipeScannerScreen(),
        NavigationOptions.weightHistoryRoute: (context) =>
            const WeightHistoryScreen(),
        NavigationOptions.fastingRoute: (context) => const FastingScreen(),
        NavigationOptions.manageProfilesRoute: (context) =>
            const ManageProfilesScreen(),
      },
    );
  }
}

/// Returning from an IME-owning route can overwrite an earlier tint refresh.
class _SystemUiReturnObserver extends NavigatorObserver {
  final VoidCallback onReturnHome;
  _SystemUiReturnObserver(this.onReturnHome);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst == true) onReturnHome();
  }
}
