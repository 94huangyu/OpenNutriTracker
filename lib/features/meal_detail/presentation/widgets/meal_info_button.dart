import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/fdc/fdc_const.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/off_disclaimer.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class MealInfoButton extends StatelessWidget {
  final String? url;
  final MealSourceEntity source;

  /// Backend food_source.code for Supabase foods ('fdc_sr_legacy',
  /// 'bls'...); lets the button name the actual database instead of the
  /// generic FoodData Central label. Null for OFF/custom meals and
  /// legacy cached entries.
  final String? backendSource;
  final String? originalSource;
  final String? originalCode;

  const MealInfoButton({
    super.key,
    required this.url,
    required this.source,
    this.backendSource,
    this.originalSource,
    this.originalCode,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildSource(context),
      Semantics(
        identifier: 'meal-nutrition-source-info',
        child: TextButton.icon(
          icon: const Icon(Icons.info_outline_rounded, size: 20),
          label: Text(S.of(context).foodNutritionSourceInfo),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(S.of(context).foodNutritionSourceInfo),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.of(context).foodNutritionScopeHint),
                    if (source == MealSourceEntity.off ||
                        originalSource == 'off') ...[
                      const SizedBox(height: 16),
                      const OffDisclaimer(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.of(context).dialogCloseLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildSource(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final infoUrl = _getInfoUrl();
    final uri = Uri.tryParse(infoUrl);
    final canOpen =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    final referenceName = originalSource == 'off'
        ? OFFConst.offSourceName
        : SPConst.foodSourceDisplayNames[originalSource ?? backendSource] ??
              (originalSource == 'fdc'
                  ? S.of(context).additionalInfoLabelFDC
                  : originalSource) ??
              (Uri.tryParse(url ?? '')?.host.isNotEmpty == true
                  ? Uri.tryParse(url!)!.host
                  : null);
    final reference = source == MealSourceEntity.custom && referenceName != null
        ? '$referenceName${originalCode == null ? "" : " · $originalCode"}'
        : null;
    if (source == MealSourceEntity.custom && reference == null) {
      return Text(S.of(context).myFoodLabel);
    }
    return Semantics(
      identifier: 'meal-info-source',
      child: TextButton.icon(
        onPressed: canOpen ? () => _launchUrl(infoUrl) : null,
        icon: Icon(Icons.open_in_new_rounded, size: 20, color: accent),
        label: Text(
          reference == null
              ? _getInfoLabelText(context)
              : '${S.of(context).myFoodLabel} · ${S.of(context).customMealReference(reference)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _getInfoUrl() {
    String siteUrl;
    switch (source) {
      case MealSourceEntity.unknown:
        siteUrl = "";
        break;
      case MealSourceEntity.custom:
        siteUrl =
            url ??
            SPConst.foodSourceWebsites[originalSource ?? backendSource] ??
            (originalSource == 'off' ? OFFConst.offWebsiteUrl : "");
        break;
      case MealSourceEntity.off:
        siteUrl = url ?? OFFConst.offWebsiteUrl;
        break;
      case MealSourceEntity.fdc:
        // Foods without a per-item detail page (BLS, INDB, TBCA...) link
        // to their database's website instead.
        siteUrl =
            url ??
            SPConst.foodSourceWebsites[backendSource] ??
            FDCConst.fdcWebsiteUrl;
        break;
      case MealSourceEntity.recipe:
        siteUrl = "";
        break;
    }
    return siteUrl;
  }

  String _getInfoLabelText(BuildContext context) {
    String infoLabel;
    switch (source) {
      case MealSourceEntity.unknown:
        infoLabel = S.of(context).additionalInfoLabelUnknown;
        break;
      case MealSourceEntity.custom:
        infoLabel = S.of(context).additionalInfoLabelCustom;
        break;
      case MealSourceEntity.off:
        infoLabel = S.of(context).additionalInfoLabelOFF;
        break;
      case MealSourceEntity.fdc:
        final sourceName = SPConst.foodSourceDisplayNames[backendSource];
        infoLabel = sourceName != null
            ? S.of(context).additionalInfoLabelSource(sourceName)
            : S.of(context).additionalInfoLabelFDC;
        break;
      case MealSourceEntity.recipe:
        infoLabel = S.of(context).additionalInfoLabelRecipe;
        break;
    }
    return infoLabel;
  }

  Future<void> _launchUrl(String siteUrl) async {
    if (!await launchUrl(
      Uri.parse(siteUrl),
      mode: LaunchMode.externalApplication,
    )) {}
  }
}
