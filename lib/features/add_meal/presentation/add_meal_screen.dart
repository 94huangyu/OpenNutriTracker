import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/personal_food_list.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/add_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/screens/bulk_add_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/search_source_notice.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/quick_add_bottom_sheet.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/util/meal_relevance_ranker.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/scanner/util/barcode_check_digit.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final ValueNotifier<String> _searchStringListener = ValueNotifier('');

  PersonalFoodDataSource? _personalFoods;
  void _personalChanged() {
    if (mounted) setState(() {});
  }

  late AddMealType _mealType;
  late DateTime _day;

  late AddMealBloc _addMealBloc;
  late ProductsBloc _productsBloc;
  late FoodBloc _foodBloc;
  late RecentMealBloc _recentMealBloc;

  // Single smart search: one field, one results list, and source-filter chips.
  // Opens on Recent (fast re-logging); typing searches Products by default,
  // with Food / Recent a chip away.
  _SearchSource _source = _SearchSource.recent;

  @override
  void initState() {
    if (locator.isRegistered<PersonalFoodDataSource>()) {
      _personalFoods = locator<PersonalFoodDataSource>()
        ..addListener(_personalChanged);
    }
    _addMealBloc = locator<AddMealBloc>()..add(InitializeAddMealEvent());
    _productsBloc = locator<ProductsBloc>();
    _foodBloc = locator<FoodBloc>();
    _recentMealBloc = locator<RecentMealBloc>()
      ..add(const LoadRecentMealEvent(searchString: ""));
    super.initState();
  }

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AddMealScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _personalFoods?.removeListener(_personalChanged);
    _searchStringListener.dispose();
    _addMealBloc.close();
    _productsBloc.close();
    _foodBloc.close();
    _recentMealBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final secondaryAction = OutlinedButton.styleFrom(
      backgroundColor: palette.surface,
      foregroundColor: palette.textStrong,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
    );
    return Scaffold(
      // Let the keyboard overlay the results rather than compress the body.
      // In landscape the space above the keyboard is shorter than the pinned
      // search bar + tab bar, which otherwise overflows (issue #165 testing).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(S.of(context).recordingAddFood),
        actions: [
          BlocBuilder<AddMealBloc, AddMealState>(
            bloc: _addMealBloc,
            builder: (context, state) => Semantics(
              identifier: 'add-meal-more',
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'quick') _onQuickAddPressed();
                  if (value == 'bulk' && state is AddMealLoadedState) {
                    _onBulkAddPressed(state.usesImperialUnits);
                  }
                  if (value == 'mine') _selectSource(_SearchSource.mine);
                  if (value == 'products') {
                    _selectSource(_SearchSource.products);
                  }
                  if (value == 'food') _selectSource(_SearchSource.food);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'quick',
                    child: Text(S.of(context).quickAddCardLabel),
                  ),
                  PopupMenuItem(
                    value: 'bulk',
                    enabled: state is AddMealLoadedState,
                    child: Text(S.of(context).bulkAddTitle),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'mine',
                    child: Text(S.of(context).myFoodLabel),
                  ),
                  PopupMenuItem(
                    value: 'products',
                    child: Text(S.of(context).searchProductsPage),
                  ),
                  PopupMenuItem(
                    value: 'food',
                    child: Text(S.of(context).searchFoodPage),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_day)} · ${_mealType.getTypeName(context)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              MealSearchBar(
                searchStringListener: _searchStringListener,
                onSearchSubmit: _onSearchSubmit,
                onSearchChanged: _onSearchChanged,
                onBarcodePressed: null,
                outlined: true,
              ),
              const SizedBox(height: Dimens.spacing12),
              BlocBuilder<AddMealBloc, AddMealState>(
                bloc: _addMealBloc,
                builder: (context, state) => LayoutBuilder(
                  builder: (context, constraints) {
                    var buttonWidth = 0.0;
                    for (final label in [
                      S.of(context).recordingScanFood,
                      S.of(context).noResultsCreateCustomFood,
                    ]) {
                      final painter = TextPainter(
                        text: TextSpan(
                          text: label,
                          style: secondaryAction.textStyle?.resolve({}),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout();
                      // Icon, icon gap and the explicit horizontal padding.
                      final width = painter.width + 18 + 8 + 24;
                      if (width > buttonWidth) buttonWidth = width;
                      painter.dispose();
                    }
                    final width = constraints.maxWidth >= buttonWidth * 2 + 12
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: Semantics(
                            identifier: 'add-meal-scan',
                            child: OutlinedButton.icon(
                              style: secondaryAction,
                              onPressed: _onBarcodeIconPressed,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              label: Text(S.of(context).recordingScanFood),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: Semantics(
                            identifier: 'add-meal-custom-add',
                            child: OutlinedButton.icon(
                              style: secondaryAction,
                              onPressed: state is AddMealLoadedState
                                  ? () => _onCustomAddButtonPressed(
                                      state.usesImperialUnits,
                                    )
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(
                                S.of(context).noResultsCreateCustomFood,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildSourceChips(context, palette),
              const SizedBox(height: Dimens.spacing12),
              // Rebuild on every keystroke so the empty-state logic can tell
              // "no results for this query" apart from "a newer query is
              // still debouncing/searching" — the latter shows a spinner.
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _searchStringListener,
                  builder: (context, query, _) =>
                      _buildResults(context, palette, query),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onProductsRefreshButtonPressed() {
    _productsBloc.add(const RefreshProductsEvent());
  }

  void _onFoodRefreshButtonPressed() {
    _foodBloc.add(const RefreshFoodEvent());
  }

  void _onRecentMealsRefreshButtonPressed() {
    _recentMealBloc.add(const LoadRecentMealEvent(searchString: ""));
  }

  /// Resolves the source to search for a query: an empty query always returns
  /// to Recent; a non-empty query searches Products by default, unless the user
  /// has explicitly chosen Food. Keeps the chip selection and the results in sync.
  _SearchSource _resolveSource(String trimmed) {
    if (_source == _SearchSource.mine || _source == _SearchSource.favorites) {
      return _source;
    }
    if (trimmed.isEmpty) return _SearchSource.recent;
    // Typing searches every source at once (All); an explicit Products / Food
    // choice narrows that merged list.
    return _source == _SearchSource.recent ? _SearchSource.all : _source;
  }

  bool _searchesProducts(_SearchSource s) =>
      s == _SearchSource.all || s == _SearchSource.products;
  bool _searchesFood(_SearchSource s) =>
      s == _SearchSource.all || s == _SearchSource.food;

  void _onSearchSubmit(String inputText) {
    final trimmed = inputText.trim();
    final source = _resolveSource(trimmed);
    if (source != _source) setState(() => _source = source);
    // A scannable barcode jumps straight to the scanner (product sources only).
    if (_searchesProducts(source) && isValidBarcodeCheckDigit(trimmed)) {
      Navigator.of(context).pushNamed(
        NavigationOptions.scannerRoute,
        arguments: ScannerScreenArguments(
          _day,
          _mealType.getIntakeType(),
          initialBarcode: trimmed,
        ),
      );
      return;
    }
    if (_searchesProducts(source)) {
      _productsBloc.add(LoadProductsEvent(searchString: inputText));
    }
    if (_searchesFood(source)) {
      _foodBloc.add(LoadFoodEvent(searchString: inputText));
    }
    if (source == _SearchSource.recent) {
      _productsBloc.add(const LoadProductsEvent(searchString: ''));
      _foodBloc.add(const LoadFoodEvent(searchString: ''));
      _recentMealBloc.add(LoadRecentMealEvent(searchString: inputText));
    }
  }

  /// Debounced search-as-you-type. Recent filters local intake history; the
  /// remote sources debounce via their own *InputChanged events. "All" searches
  /// products and food together into one merged list.
  void _onSearchChanged(String inputText) {
    final trimmed = inputText.trim();
    final source = _resolveSource(trimmed);
    if (source != _source) setState(() => _source = source);
    if (_searchesProducts(source)) {
      _productsBloc.add(SearchInputChangedEvent(searchString: inputText));
    }
    if (_searchesFood(source)) {
      _foodBloc.add(SearchFoodInputChangedEvent(searchString: inputText));
    }
    if (source == _SearchSource.recent) {
      _productsBloc.add(const LoadProductsEvent(searchString: ''));
      _foodBloc.add(const LoadFoodEvent(searchString: ''));
      _recentMealBloc.add(LoadRecentMealEvent(searchString: inputText));
    }
  }

  void _selectSource(_SearchSource source) {
    setState(() => _source = source);
    final query = _searchStringListener.value;
    if (_searchesProducts(source)) {
      _productsBloc.add(LoadProductsEvent(searchString: query));
    }
    if (_searchesFood(source)) {
      _foodBloc.add(LoadFoodEvent(searchString: query));
    }
    if (source == _SearchSource.recent) {
      _recentMealBloc.add(LoadRecentMealEvent(searchString: query));
    }
  }

  Widget _buildSourceChips(BuildContext context, AppPalette palette) {
    Widget chip(_SearchSource source, String label) => Padding(
      padding: const EdgeInsets.only(right: Dimens.spacing8),
      child: Semantics(
        identifier: 'search-source-${source.name}',
        child: ChoiceChip(
          label: Text(label),
          selected: _source == source,
          selectedColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .12),
          side: BorderSide(
            color: _source == source
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
          labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _source == source
                ? Theme.of(context).colorScheme.primary
                : palette.textMuted,
            fontWeight: _source == source ? FontWeight.w600 : FontWeight.w400,
          ),
          showCheckmark: false,
          onSelected: (_) => _selectSource(source),
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip(_SearchSource.all, S.of(context).allItemsLabel),
            chip(_SearchSource.recent, S.of(context).recentlyAddedLabel),
            chip(_SearchSource.favorites, S.of(context).foodFavorites),
            if (_source == _SearchSource.mine)
              chip(_SearchSource.mine, S.of(context).myFoodLabel),
            if (_source == _SearchSource.products)
              chip(_SearchSource.products, S.of(context).searchProductsPage),
            if (_source == _SearchSource.food)
              chip(_SearchSource.food, S.of(context).searchFoodPage),
          ],
        ),
      ),
    );
  }

  Widget _resultsHeader(BuildContext context, AppPalette palette) => Container(
    padding: const EdgeInsets.symmetric(vertical: Dimens.spacing4),
    alignment: Alignment.centerLeft,
    child: Text(
      S.of(context).searchResultsLabel,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: palette.textMuted,
      ),
    ),
  );

  Widget _remoteResults(
    BuildContext context,
    String query, {
    ProductsState? productsState,
    FoodState? foodState,
  }) {
    if (query.trim().isEmpty) return const DefaultsResultsWidget();
    final products =
        productsState is ProductsLoadedState && productsState.query == query
        ? productsState
        : null;
    final food = foodState is FoodLoadedState && foodState.query == query
        ? foodState
        : null;
    final merged = mergeAndRankMeals(
      [
        for (final meal in products?.products ?? <MealEntity>[])
          _personalFoods?.apply(meal) ?? meal,
      ],
      [
        for (final meal in food?.food ?? <MealEntity>[])
          _personalFoods?.apply(meal) ?? meal,
      ],
      query,
    );
    final imperial =
        products?.usesImperialUnits ?? food?.usesImperialUnits ?? false;
    final statuses = <(String, SearchRemoteStatus, VoidCallback)>[
      if (productsState != null)
        (
          'Open Food Facts',
          products?.remoteStatus ??
              (productsState is ProductsFailedState
                  ? SearchRemoteStatus.failed
                  : SearchRemoteStatus.loading),
          _onProductsRefreshButtonPressed,
        ),
      if (foodState != null)
        (
          S.of(context).referenceFoodSourceLabel,
          food?.remoteStatus ??
              (foodState is FoodFailedState
                  ? SearchRemoteStatus.failed
                  : SearchRemoteStatus.loading),
          _onFoodRefreshButtonPressed,
        ),
    ];
    final pending = statuses.any(
      (source) => source.$2 == SearchRemoteStatus.loading,
    );
    final incomplete = statuses.any(
      (source) => [
        SearchRemoteStatus.failed,
        SearchRemoteStatus.unconfigured,
        SearchRemoteStatus.disabled,
      ].contains(source.$2),
    );
    return Semantics(
      identifier: 'add-food-search-results',
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          FoodListSliver(
            itemCount: merged.length,
            itemBuilder: (context, index) => MealItemCard(
              day: _day,
              mealEntity: merged[index],
              addMealType: _mealType,
              usesImperialUnits: imperial,
            ),
          ),
          SliverToBoxAdapter(
            child: Semantics(
              identifier: 'search-source-details',
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  incomplete
                      ? S.of(context).searchSourcesIncomplete
                      : pending
                      ? S.of(context).searchSourcesPending
                      : S.of(context).recordingFoodSources,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: Icon(
                  incomplete ? Icons.info_outline : Icons.cloud_outlined,
                  size: 18,
                ),
                children: [
                  for (var i = 0; i < statuses.length; i++)
                    if (i == 0 ||
                        statuses[i].$2 != SearchRemoteStatus.notRequested)
                      SearchSourceNotice(
                        sourceId: statuses[i].$1 == 'Open Food Facts'
                            ? 'off'
                            : 'reference',
                        source: statuses[i].$1,
                        status: statuses[i].$2,
                        onRetry: statuses[i].$3,
                      ),
                ],
              ),
            ),
          ),
          if (merged.isEmpty && !pending)
            SliverToBoxAdapter(
              child: NoResultsWidget(
                title: incomplete ? S.of(context).noLocalSearchResults : null,
                onScanBarcode: _onBarcodeIconPressed,
                onCreateCustomFood: () => _onCustomAddButtonPressed(imperial),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppPalette palette, String query) {
    switch (_source) {
      case _SearchSource.mine:
      case _SearchSource.favorites:
        return PersonalFoodList(
          day: _day,
          addMealType: _mealType,
          query: query,
          favoritesOnly: _source == _SearchSource.favorites,
        );
      case _SearchSource.all:
      case _SearchSource.products:
      case _SearchSource.food:
        return Column(
          children: [
            _resultsHeader(context, palette),
            Expanded(
              child: BlocBuilder<ProductsBloc, ProductsState>(
                bloc: _productsBloc,
                builder: (context, ps) => BlocBuilder<FoodBloc, FoodState>(
                  bloc: _foodBloc,
                  builder: (context, fs) => _remoteResults(
                    context,
                    query,
                    productsState: _searchesProducts(_source) ? ps : null,
                    foodState: _searchesFood(_source) ? fs : null,
                  ),
                ),
              ),
            ),
          ],
        );
      case _SearchSource.recent:
        return BlocBuilder<RecentMealBloc, RecentMealState>(
          bloc: _recentMealBloc,
          builder: (context, state) {
            if (state is RecentMealInitial) {
              return const SizedBox();
            } else if (state is RecentMealLoadingState) {
              return const Padding(
                padding: EdgeInsets.only(top: 32),
                child: CircularProgressIndicator(),
              );
            } else if (state is RecentMealLoadedState) {
              if (state.recentMeals.isNotEmpty) {
                return Semantics(
                  identifier: 'add-food-recent-results',
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      FoodListSliver(
                        itemCount: state.recentMeals.length,
                        itemBuilder: (context, index) {
                          return MealItemCard(
                            day: _day,
                            mealEntity:
                                _personalFoods?.apply(
                                  state.recentMeals[index],
                                ) ??
                                state.recentMeals[index],
                            addMealType: _mealType,
                            usesImperialUnits: state.usesImperialUnits,
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.viewInsetsOf(context).bottom + 16,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (query.trim().isEmpty) {
                return EmptyHint(
                  icon: Icons.history_rounded,
                  title: S.of(context).noMealsRecentlyAddedLabel,
                );
              }
              return NoResultsWidget(
                onScanBarcode: _onBarcodeIconPressed,
                onCreateCustomFood: () =>
                    _onCustomAddButtonPressed(state.usesImperialUnits),
              );
            } else if (state is RecentMealFailedState) {
              return ErrorDialog(
                errorText: S.of(context).noMealsRecentlyAddedLabel,
                onRefreshPressed: _onRecentMealsRefreshButtonPressed,
              );
            }
            return const SizedBox();
          },
        );
    }
  }

  void _onBarcodeIconPressed() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(_day, _mealType.getIntakeType()),
    );
  }

  void _onBulkAddPressed(bool usesImperialUnits) {
    Navigator.of(context).pushNamed(
      NavigationOptions.bulkAddRoute,
      arguments: BulkAddScreenArguments(
        _mealType.getIntakeType(),
        _day,
        usesImperialUnits,
      ),
    );
  }

  void _onQuickAddPressed() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          QuickAddBottomSheet(intakeType: _mealType.getIntakeType(), day: _day),
    );
  }

  void _onCustomAddButtonPressed(bool usesImperialUnits) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pushNamed(
      NavigationOptions.editMealRoute,
      arguments: EditMealScreenArguments(
        _day,
        MealEntity.empty(),
        _mealType.getIntakeType(),
        usesImperialUnits,
      ),
    );
  }
}

class AddMealScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  AddMealScreenArguments(this.mealType, this.day);
}

enum _SearchSource { recent, mine, favorites, all, products, food }
