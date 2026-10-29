import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// A single outlined group that keeps long libraries lazily built.
class FoodLibraryList extends StatelessWidget {
  final String title;
  final String? hint;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const FoodLibraryList({
    super.key,
    required this.title,
    this.hint,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return Semantics(
      identifier: 'food-library-list',
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(S.of(context).libraryItemCount(itemCount)),
                    ],
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      hint!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            sliver: FoodListSliver(
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

/// One outlined food group; rows stay lazy, including long search results.
class FoodListSliver extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const FoodListSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SliverToBoxAdapter();
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
      ),
      sliver: SliverList.separated(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 1,
          indent: 12,
          endIndent: 12,
          color: palette.border,
        ),
      ),
    );
  }
}

class FoodLibraryTile extends StatelessWidget {
  final String title;
  final String? brand;
  final String detail;
  final Widget leading;
  final Widget trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const FoodLibraryTile({
    super.key,
    required this.title,
    this.brand,
    required this.detail,
    required this.leading,
    required this.trailing,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: .12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: (theme.textTheme.bodySmall ?? const TextStyle())
                          .copyWith(color: palette.textMuted),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          if (brand?.trim().isNotEmpty ?? false)
                            Text(
                              brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            detail
                                .replaceAll(' kcal', '\u00a0kcal')
                                .replaceAll(' kJ', '\u00a0kJ'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
