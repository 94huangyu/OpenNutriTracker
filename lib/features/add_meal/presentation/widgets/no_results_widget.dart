import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/generated/l10n.dart';

class NoResultsWidget extends StatelessWidget {
  final String? title;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onCreateCustomFood;

  const NoResultsWidget({
    super.key,
    this.title,
    this.onScanBarcode,
    this.onCreateCustomFood,
  });

  @override
  Widget build(BuildContext context) {
    final showActions = onScanBarcode != null || onCreateCustomFood != null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyHint(
            icon: Icons.search_off_rounded,
            title: title ?? S.of(context).noResultsFound,
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing24),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: Dimens.spacing8,
                runSpacing: Dimens.spacing8,
                children: [
                  if (onScanBarcode != null)
                    Semantics(
                      identifier: 'search-no-results-scan-barcode',
                      child: OutlinedButton.icon(
                        onPressed: onScanBarcode,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(S.of(context).noResultsScanBarcode),
                      ),
                    ),
                  if (onCreateCustomFood != null)
                    Semantics(
                      identifier: 'search-no-results-create-custom-food',
                      child: FilledButton.tonalIcon(
                        onPressed: onCreateCustomFood,
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(S.of(context).noResultsCreateCustomFood),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
