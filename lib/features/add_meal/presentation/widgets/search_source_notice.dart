import 'package:flutter/material.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Compact source feedback never labels existing local matches as "not found".
class SearchSourceNotice extends StatelessWidget {
  final String source;
  final SearchRemoteStatus status;
  final VoidCallback onRetry;
  final String sourceId;
  const SearchSourceNotice({
    super.key,
    required this.source,
    required this.status,
    required this.onRetry,
    required this.sourceId,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = switch (status) {
      SearchRemoteStatus.loading => s.searchSourceLoading(source),
      SearchRemoteStatus.empty => s.searchSourceEmpty(source),
      SearchRemoteStatus.failed => s.searchSourceFailed(source),
      SearchRemoteStatus.unconfigured => s.searchSourceUnconfigured(source),
      SearchRemoteStatus.disabled => s.searchSourceDisabled(source),
      SearchRemoteStatus.notRequested => s.searchLocalOnly,
      SearchRemoteStatus.results => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == SearchRemoteStatus.loading) ...[
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (status == SearchRemoteStatus.failed)
            Semantics(
              identifier: 'search-source-$sourceId-retry',
              child: IconButton(
                onPressed: onRetry,
                tooltip: s.retryLabel,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
