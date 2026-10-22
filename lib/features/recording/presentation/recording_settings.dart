import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/profile_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/profile_entity.dart';
import 'package:opennutritracker/core/domain/usecase/switch_profile_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/update_profile_usecase.dart';
import 'package:opennutritracker/core/l10n/shipped_locales.dart';
import 'package:opennutritracker/core/utils/app_locale_service.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locale_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/full_backup_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/food_sources_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Local identity and recording preferences; never loads the body ProfileBloc.
class RecordingSettings extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const RecordingSettings({super.key, this.onDataChanged});
  @override
  State<RecordingSettings> createState() => _RecordingSettingsState();
}

class _RecordingSettingsState extends State<RecordingSettings> {
  ConfigEntity? _config;
  bool _busy = false;
  bool _failed = false;
  int _formRevision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await locator<ConfigRepository>().getConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _formRevision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).recordingSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed() {
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
    widget.onDataChanged?.call();
  }

  Future<void> _restored() async {
    final config = await locator<ConfigRepository>().getConfig();
    if (!mounted) return;
    final theme = context.read<ThemeModeProvider>();
    theme.updateTheme(config.appTheme);
    theme.updateUseMaterialYou(config.useMaterialYou);
    theme.updateAccentColor(config.accentColor);
    context.read<EnergyUnitProvider>().updateUsesKilojoules(
      config.usesKilojoules,
    );
    context.read<LocaleProvider>().updateLocale(
      config.selectedLocale == null ? null : Locale(config.selectedLocale!),
    );
    await AppLocaleService.setApplicationLocale(config.selectedLocale);
    await _load();
    if (mounted) _changed();
  }

  Future<void> _rename(ProfileEntity profile) async {
    var input = profile.name;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).m4ProfileName),
        content: Semantics(
          identifier: 'recording-profile-name',
          child: TextFormField(
            initialValue: profile.name,
            onChanged: (value) => input = value,
            maxLength: 80,
            autofocus: true,
            decoration: InputDecoration(hintText: S.of(context).m4LocalProfile),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.trim()),
            child: Text(S.of(context).recordingSave),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    await _run(() async {
      await locator<UpdateProfileUsecase>().updateProfile(
        ProfileEntity(
          id: profile.id,
          name: name,
          createdAt: profile.createdAt,
          boxSuffix: profile.boxSuffix,
          imagePath: profile.imagePath,
        ),
      );
      _changed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = context.watch<ThemeModeProvider>();
    final energy = context.watch<EnergyUnitProvider>();
    final locale = context.watch<LocaleProvider>();
    final config = _config;
    final profiles = locator<ProfileRepository>().getAllProfiles();
    final active = locator<HiveDBProvider>().activeProfileId;
    final profile = profiles.where((p) => p.id == active).firstOrNull;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(s.m4My)),
        body: SafeArea(
          top: false,
          child: _failed
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text(s.recordingSaveFailed),
                  ),
                )
              : config == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    Text(
                      s.m4LocalProfile,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(s.m4ProfileHint),
                    const SizedBox(height: 12),
                    Semantics(
                      identifier: 'recording-profile-select',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('$active/$_formRevision'),
                        initialValue: active,
                        isExpanded: true,
                        items: [
                          for (var i = 0; i < profiles.length; i++)
                            DropdownMenuItem(
                              value: profiles[i].id,
                              child: Text(
                                profiles[i].name.isEmpty
                                    ? '${s.m4LocalProfile} ${i + 1}'
                                    : profiles[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) => _run(() async {
                                final target = profiles.firstWhere(
                                  (p) => p.id == id,
                                );
                                await locator<SwitchProfileUsecase>()
                                    .switchProfile(target);
                                if (mounted) _changed();
                              }),
                      ),
                    ),
                    if (profile != null)
                      Semantics(
                        identifier: 'recording-profile-rename',
                        child: TextButton(
                          onPressed: _busy ? null : () => _rename(profile),
                          child: Text(s.m4ProfileName),
                        ),
                      ),
                    const Divider(height: 32),
                    Semantics(
                      identifier: 'recording-settings-language',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('locale-${locale.locale}/$_formRevision'),
                        initialValue: locale.locale?.languageCode ?? '',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.settingsLanguageLabel,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(s.recordingThemeSystem),
                          ),
                          for (final e in shippedLocales.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => _run(() async {
                                final selected = value == '' ? null : value;
                                await locator<ConfigRepository>()
                                    .setSelectedLocale(selected);
                                await AppLocaleService.setApplicationLocale(
                                  selected,
                                );
                                if (context.mounted) {
                                  context.read<LocaleProvider>().updateLocale(
                                    selected == null ? null : Locale(selected),
                                  );
                                }
                              }),
                      ),
                    ),
                    Semantics(
                      identifier: 'recording-settings-kj',
                      child: SwitchListTile(
                        title: Text(s.recordingUseKj),
                        subtitle: const Text('kcal ↔ kJ'),
                        value: energy.usesKilojoules,
                        onChanged: _busy
                            ? null
                            : (value) => _run(() async {
                                await locator<ConfigRepository>()
                                    .setConfigUsesKilojoules(value);
                                if (mounted) energy.updateUsesKilojoules(value);
                              }),
                      ),
                    ),
                    Semantics(
                      identifier: 'recording-settings-theme',
                      child: DropdownButtonFormField<AppThemeEntity>(
                        key: ValueKey('${theme.appTheme}/$_formRevision'),
                        initialValue: theme.appTheme,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.recordingTheme,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: AppThemeEntity.system,
                            child: Text(s.recordingThemeSystem),
                          ),
                          DropdownMenuItem(
                            value: AppThemeEntity.light,
                            child: Text(s.recordingThemeLight),
                          ),
                          DropdownMenuItem(
                            value: AppThemeEntity.dark,
                            child: Text(s.recordingThemeDark),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => _run(() async {
                                if (value == null) return;
                                await locator<ConfigRepository>()
                                    .setConfigAppTheme(value);
                                if (mounted) theme.updateTheme(value);
                              }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      identifier: 'recording-settings-day-boundary',
                      child: ListTile(
                        title: Text(s.settingsDayStartLabel),
                        subtitle: Text(
                          TimeOfDay(
                            hour: config.dayStartOffsetHours,
                            minute: config.dayStartOffsetMinutes,
                          ).format(context),
                        ),
                        onTap: _busy
                            ? null
                            : () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: config.dayStartOffsetHours,
                                    minute: config.dayStartOffsetMinutes,
                                  ),
                                );
                                if (time == null || !mounted) return;
                                await _run(() async {
                                  final repo = locator<ConfigRepository>();
                                  await repo.setConfigDayStartOffset(
                                    time.hour,
                                    time.minute,
                                  );
                                  if (mounted) _changed();
                                });
                              },
                      ),
                    ),
                    Semantics(
                      identifier: 'recording-settings-backup',
                      child: ListTile(
                        leading: const Icon(Icons.backup_outlined),
                        title: Text(s.m4BackupTitle),
                        onTap: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      FullBackupScreen(onRestored: _restored),
                                ),
                              ),
                      ),
                    ),
                    Semantics(
                      identifier: 'recording-settings-privacy',
                      child: ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: Text(s.m4Privacy),
                        onTap: _busy
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(s.m4Privacy),
                                  content: Text(s.m4PrivacyDescription),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(s.dialogOKLabel),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Semantics(
                      identifier: 'recording-settings-sources',
                      child: ListTile(
                        leading: const Icon(Icons.storage_outlined),
                        title: Text(s.recordingFoodSources),
                        onTap: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const FoodSourcesScreen(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
