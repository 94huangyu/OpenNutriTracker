import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/export_import_dialog.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/food_sources_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Record-focused preferences, without loading the legacy ProfileBloc.
class RecordingSettings extends StatelessWidget {
  const RecordingSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = context.watch<ThemeModeProvider>();
    final energy = context.watch<EnergyUnitProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsLabel)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              identifier: 'recording-settings-kj',
              child: SwitchListTile(
                title: Text(s.recordingUseKj),
                subtitle: const Text('kcal ↔ kJ'),
                value: energy.usesKilojoules,
                onChanged: (value) async {
                  await locator<ConfigRepository>().setConfigUsesKilojoules(
                    value,
                  );
                  energy.updateUsesKilojoules(value);
                },
              ),
            ),
            Semantics(
              identifier: 'recording-settings-theme',
              child: DropdownButtonFormField<AppThemeEntity>(
                initialValue: theme.appTheme,
                decoration: InputDecoration(labelText: s.recordingTheme),
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
                onChanged: (value) async {
                  if (value == null) return;
                  await locator<ConfigRepository>().setConfigAppTheme(value);
                  theme.updateTheme(value);
                },
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'recording-settings-backup',
              child: ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(s.exportImportAppDataLabel),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ExportImportDialog(),
                ),
              ),
            ),
            Semantics(
              identifier: 'recording-settings-sources',
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(s.recordingFoodSources),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FoodSourcesScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
