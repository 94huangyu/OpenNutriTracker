import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/personal_food_actions.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';
import 'package:opennutritracker/core/utils/demo/unsplash_attribution.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/util/meal_quantity_converter.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_bottom_sheet.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/food_portion_summary.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/off_disclaimer.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  static const String _initialQuantityMetric = '100';
  static const String _initialQuantityImperial = '1';

  final log = Logger('ItemDetailScreen');

  late MealDetailBloc _mealDetailBloc;

  late MealEntity meal;
  PersonalFoodDataSource? get _personalFoods =>
      locator.isRegistered<PersonalFoodDataSource>()
      ? locator<PersonalFoodDataSource>()
      : null;
  late DateTime _day;
  late IntakeTypeEntity intakeTypeEntity;

  final quantityTextController = TextEditingController();
  late bool _usesImperialUnits;
  bool _browseOnly = false;
  bool _showMicronutrients = false;
  // #1126: preloaded from `ConfigEntity.defaultToRawFoodUnits`. False keeps
  // the pre-existing "serving wins whenever one exists" default; true
  // steers `_applyInitialSelection` to grams/oz (or ml/fl oz) instead.
  bool _defaultToRawFoodUnits = false;

  String _initialUnit = "";
  String _initialQuantity = "";

  // Set on the first didChangeDependencies pass, which is the only one that
  // reads the route arguments and requests hydration (see there).
  bool _argumentsRead = false;
  bool _userChangedSelection = false;
  double? _baseQuantity;
  bool _switchingUnit = false;

  /// True while `_applyInitialSelection` is running. The bottom sheet's
  /// text-change listener echoes every write to `quantityTextController`
  /// back through [onQuantityOrUnitChanged], including the ones this
  /// method makes itself, and its `widget.selectedUnit` is the last
  /// rendered value — not the unit we're currently switching to. Without
  /// this guard the echo would (a) dispatch a stale-unit UpdateKcalEvent
  /// on top of the explicit one below, (b) flip [_userChangedSelection]
  /// to true although nobody touched anything, and (c) call
  /// `_scrollToCalorieText` on open — enough scroll to collapse the app
  /// bar and push the product image out of view.
  bool _applyingInitialSelection = false;

  @override
  void initState() {
    _mealDetailBloc = locator<MealDetailBloc>();
    _loadDetailPreferences();
    super.initState();
  }

  @override
  void dispose() {
    quantityTextController.dispose();
    _mealDetailBloc.close();
    super.dispose();
  }

  Future<void> _loadDetailPreferences() async {
    final config = await locator<GetConfigUsecase>().getConfig();
    if (!mounted) return;
    final wasSelectionInitialised = _initialUnit != "";
    setState(() {
      _showMicronutrients = config.showMicronutrients;
      _defaultToRawFoodUnits = config.defaultToRawFoodUnits;
    });
    // #1126: the config read is async, so `_applyInitialSelection` may have
    // already run with the fallback default of "prefer serving". Re-pick
    // if the user hasn't touched selection yet, so opting into raw units
    // still switches the very first render's dropdown to grams/oz.
    if (wasSelectionInitialised &&
        _defaultToRawFoodUnits &&
        !_userChangedSelection) {
      _initialUnit = "";
      _initialQuantity = "";
      _applyInitialSelection();
    }
  }

  @override
  void didChangeDependencies() {
    // `ModalRoute.of` re-runs this whenever a route is pushed over or popped
    // off this screen — the unit dropdown's own menu included — so the
    // arguments are read once. Re-reading `meal` on every pass handed the
    // thin search hit back to the sheet the moment the dropdown opened,
    // after hydration had already swapped in the full record: the serving
    // entry the user then tapped was no longer in the rebuilt list and the
    // button went blank (#1216).
    if (!_argumentsRead) {
      final args =
          ModalRoute.of(context)?.settings.arguments
              as MealDetailScreenArguments;
      meal = _personalFoods?.apply(args.mealEntity) ?? args.mealEntity;
      _day = args.day;
      intakeTypeEntity = args.intakeTypeEntity;
      _usesImperialUnits = args.usesImperialUnits;
      _browseOnly = args.browseOnly;
      _argumentsRead = true;

      // Thin OFF search results get hydrated to the full product record
      // (serving fields + micronutrients) once, in the background; the
      // listener in build() swaps the displayed meal in when it arrives.
      _mealDetailBloc.add(HydrateMealEvent(meal));
    }

    if (!_browseOnly) _mealDetailBloc.add(LoadDailyTotalsEvent(_day));

    _applyInitialSelection();

    super.didChangeDependencies();
  }

  /// Pick the default unit and quantity from the meal's shape. Serving-based
  /// meals default to 1 serving; otherwise to 100 g/ml (or 1 oz/fl oz in
  /// imperial). Guarded so it only runs while the user hasn't chosen yet, and
  /// re-run after hydration reveals serving values.
  void _applyInitialSelection() {
    // #1126: when the user has opted into raw units in Settings, the
    // scalable-serving branch is skipped so grams/oz (or ml/fl oz)
    // becomes the very first render's default. `hasScalableServing`
    // stays the classifier — a record with no parseable serving still
    // falls through to weight/volume the same way it always did.
    final preferServing =
        meal.scalableServingQuantity != null && !_defaultToRawFoodUnits;

    _applyingInitialSelection = true;
    try {
      if (_initialUnit == "") {
        // `scalableServingQuantity`, not `hasServingValues` (#629): the latter
        // is true for a record whose serving is unparseable text, and nothing
        // can scale those — they defaulted to "1 serving" and logged 1 g.
        if (preferServing) {
          _initialUnit = UnitDropdownItem.serving.toString();
        } else if (meal.isLiquid) {
          _initialUnit = _usesImperialUnits
              ? UnitDropdownItem.flOz.toString()
              : UnitDropdownItem.ml.toString();
        } else if (meal.isSolid) {
          _initialUnit = _usesImperialUnits
              ? UnitDropdownItem.oz.toString()
              : UnitDropdownItem.g.toString();
        } else {
          _initialUnit = UnitDropdownItem.gml.toString();
        }
        _mealDetailBloc.add(
          UpdateKcalEvent(meal: meal, selectedUnit: _initialUnit),
        );
      }

      if (_initialQuantity == "") {
        // Gated the same way as the unit above, so a bare "1" can never end
        // up beside a weight unit.
        if (preferServing) {
          _initialQuantity = "1";
          quantityTextController.text = "1";
        } else if (_usesImperialUnits) {
          _initialQuantity = _initialQuantityImperial;
          quantityTextController.text = _initialQuantityImperial;
        } else {
          _initialQuantity = _initialQuantityMetric;
          quantityTextController.text = _initialQuantityMetric;
        }
        // The unit rides along, not just the quantity: on the re-pick after
        // hydration the bottom sheet is already listening to the controller,
        // and the write above echoes back through onQuantityOrUnitChanged
        // with the unit the sheet last rendered (#1216). That echo is also
        // what `_applyingInitialSelection` makes `onQuantityOrUnitChanged`
        // ignore, so neither the stale unit nor the phantom
        // `_userChangedSelection` flip nor the scroll reaches the screen.
        _mealDetailBloc.add(
          UpdateKcalEvent(
            meal: meal,
            totalQuantity: quantityTextController.text,
            selectedUnit: _initialUnit,
          ),
        );
      }
      if (!_userChangedSelection) {
        final quantity = double.tryParse(quantityTextController.text);
        _baseQuantity = quantity == null
            ? null
            : convertQuantityToBaseUnit(quantity, _initialUnit, meal);
      }
    } finally {
      _applyingInitialSelection = false;
    }
  }

  /// Apply the hydrated full product to the screen. If the user hasn't touched
  /// the quantity/unit yet, re-pick the defaults (so serving becomes the
  /// default now that serving data exists); otherwise just recompute totals
  /// against the fuller nutriments while keeping the user's selection.
  void _onMealHydrated(MealEntity full) {
    setState(() => meal = _personalFoods?.apply(full) ?? full);
    if (_userChangedSelection) {
      final quantity = double.tryParse(
        quantityTextController.text.replaceAll(',', '.'),
      );
      _baseQuantity = quantity == null
          ? null
          : convertQuantityToBaseUnit(
              quantity,
              _mealDetailBloc.state.selectedUnit,
              meal,
            );
      _mealDetailBloc.add(
        UpdateKcalEvent(
          meal: meal,
          totalQuantity: quantityTextController.text,
          selectedUnit: _mealDetailBloc.state.selectedUnit,
        ),
      );
    } else {
      _initialUnit = "";
      _initialQuantity = "";
      _applyInitialSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MealDetailBloc, MealDetailState>(
      bloc: _mealDetailBloc,
      listenWhen: (prev, curr) =>
          curr.hydratedMeal != null && curr.hydratedMeal != prev.hydratedMeal,
      listener: (context, state) => _onMealHydrated(state.hydratedMeal!),
      child: SafeArea(
        child: Scaffold(
          backgroundColor:
              (Theme.of(context).brightness == Brightness.dark
                      ? AppPalette.dark
                      : AppPalette.light)
                  .canvas,
          body: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                Expanded(
                  child: BlocBuilder<MealDetailBloc, MealDetailState>(
                    bloc: _mealDetailBloc,
                    builder: (context, state) {
                      if (state is MealDetailInitial) {
                        return _getLoadedContent(
                          context,
                          state.totalQuantityConverted,
                          state.totalKcal,
                          state.totalCarbs,
                          state.totalFat,
                          state.totalProtein,
                          state.selectedUnit,
                          state.dayKcalConsumed,
                          state.dayKcalGoal,
                          state.isHydrating,
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
                if (!_browseOnly)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .6,
                    ),
                    child: SingleChildScrollView(
                      child:
                          BlocSelector<MealDetailBloc, MealDetailState, String>(
                            bloc: _mealDetailBloc,
                            selector: (state) => state.selectedUnit,
                            builder: (context, selectedUnit) {
                              return MealDetailBottomSheet(
                                product: meal,
                                day: _day,
                                intakeTypeEntity: intakeTypeEntity,
                                selectedUnit: selectedUnit,
                                mealDetailBloc: _mealDetailBloc,
                                quantityTextController: quantityTextController,
                                onQuantityOrUnitChanged:
                                    onQuantityOrUnitChanged,
                              );
                            },
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getLoadedContent(
    BuildContext context,
    String totalQuantity,
    double totalKcal,
    double totalCarbs,
    double totalFat,
    double totalProtein,
    String selectedUnit,
    double dayKcalConsumed,
    double dayKcalGoal,
    bool isHydrating,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: MediaQuery.textScalerOf(context).scale(kToolbarHeight),
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            S.of(context).foodDetailTitle,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: _browseOnly
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(dayKcalGoal > 0 ? 68 : 0),
                  child: DailyKcalOverview(
                    dayKcalConsumed: dayKcalConsumed,
                    dayKcalGoal: dayKcalGoal,
                    currentSelectionKcal: totalKcal,
                  ),
                ),
          actions: [
            Semantics(
              identifier: 'meal-detail-edit',
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    NavigationOptions.editMealRoute,
                    arguments: EditMealScreenArguments(
                      _day,
                      meal,
                      intakeTypeEntity,
                      _usesImperialUnits,
                      editOnly: _browseOnly,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_rounded),
              ),
            ),
          ],
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        identifier: 'meal-detail-photo',
                        child: InkWell(
                          onTap: meal.mainImageUrl?.isNotEmpty == true
                              ? () => Navigator.of(context).pushNamed(
                                  NavigationOptions.imageFullScreenRoute,
                                  arguments: ImageFullScreenArguments(
                                    meal.mainImageUrl!,
                                  ),
                                )
                              : null,
                          child: Hero(
                            tag: ImageFullScreen.fullScreenHeroTag,
                            child: MealThumbnail(meal: meal, size: 56),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name ?? '',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (meal.brands?.trim().isNotEmpty ?? false)
                              Text(
                                meal.brands!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if ((double.tryParse(meal.mealQuantity ?? '') ??
                                    0) >
                                0)
                              MealValueUnitText(
                                value:
                                    double.tryParse(meal.mealQuantity ?? '') ??
                                    0,
                                meal: meal,
                                usesImperialUnits: _usesImperialUnits,
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  UnsplashCreditLine(imageUrl: meal.mainImageUrl),
                  const SizedBox(height: 20),
                  FoodPortionSummary(
                    caption: _browseOnly
                        ? S
                              .of(context)
                              .mealNutrientsPerQtyLabel(
                                meal.effectiveNutritionBasis
                                    .toString()
                                    .replaceFirst(RegExp(r'\.0$'), ''),
                                meal.mealUnit ?? 'g/ml',
                              )
                        : '${S.of(context).recordingThisPortion} · '
                              '${(double.tryParse(totalQuantity) ?? 0).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} '
                              '${meal.mealUnit ?? 'g/ml'}',
                    kcal: meal.nutriments.energyKcal100 == null
                        ? null
                        : _browseOnly
                        ? meal.nutriments.energyKcal100! *
                              meal.effectiveNutritionBasis /
                              100
                        : totalKcal,
                    carbs: meal.nutriments.carbohydrates100 == null
                        ? null
                        : _browseOnly
                        ? meal.nutriments.carbohydrates100! *
                              meal.effectiveNutritionBasis /
                              100
                        : totalCarbs,
                    protein: meal.nutriments.proteins100 == null
                        ? null
                        : _browseOnly
                        ? meal.nutriments.proteins100! *
                              meal.effectiveNutritionBasis /
                              100
                        : totalProtein,
                    fat: meal.nutriments.fat100 == null
                        ? null
                        : _browseOnly
                        ? meal.nutriments.fat100! *
                              meal.effectiveNutritionBasis /
                              100
                        : totalFat,
                  ),
                  const SizedBox(height: 24),
                  if (isHydrating)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  MealDetailNutrimentsTable(
                    product: meal,
                    usesImperialUnits: _usesImperialUnits,
                    servingQuantity: meal.servingQuantity,
                    servingUnit: meal.servingUnit,
                    showMicronutrients: _showMicronutrients,
                  ),
                  const SizedBox(height: 20),
                  if (_personalFoods != null)
                    PersonalFoodActions(
                      meal: meal,
                      store: _personalFoods!,
                      onChanged: (_) =>
                          setState(() => meal = _personalFoods!.apply(meal)),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context).foodNutritionScopeHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  MealInfoButton(
                    url: meal.url,
                    source: meal.source,
                    backendSource: meal.backendSource,
                    originalSource: meal.originalSource,
                    originalCode: meal.originalCode,
                  ),
                  meal.source == MealSourceEntity.off
                      ? const Column(
                          children: [SizedBox(height: 32), OffDisclaimer()],
                        )
                      : const SizedBox(),
                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  void onQuantityOrUnitChanged(String? quantityString, String? unit) {
    if (quantityString == null || unit == null) {
      return;
    }
    if (_applyingInitialSelection || _switchingUnit) {
      // Echo from `_applyInitialSelection`'s own controller.text write;
      // that method dispatches an authoritative UpdateKcalEvent itself.
      // Treating this as a user edit would collapse the app bar on open
      // via `_scrollToCalorieText` and record a phantom selection.
      return;
    }
    _userChangedSelection = true;
    if (unit != _mealDetailBloc.state.selectedUnit && _baseQuantity != null) {
      final factor = convertQuantityToBaseUnit(1, unit, meal);
      if (!factor.isFinite || factor <= 0) return;
      quantityString = (_baseQuantity! / factor).toString().replaceFirst(
        RegExp(r'\.0$'),
        '',
      );
      _switchingUnit = true;
      try {
        quantityTextController.text = quantityString;
      } finally {
        _switchingUnit = false;
      }
    } else {
      final quantity = double.tryParse(quantityString.replaceAll(',', '.'));
      _baseQuantity = quantity != null && quantity.isFinite && quantity > 0
          ? convertQuantityToBaseUnit(quantity, unit, meal)
          : null;
    }
    _mealDetailBloc.add(
      UpdateKcalEvent(
        meal: meal,
        totalQuantity: quantityString,
        selectedUnit: unit,
        baseQuantity: _baseQuantity,
      ),
    );
  }
}

class MealDetailScreenArguments {
  final MealEntity mealEntity;
  final IntakeTypeEntity intakeTypeEntity;
  final DateTime day;
  final bool usesImperialUnits;
  final bool browseOnly;

  MealDetailScreenArguments(
    this.mealEntity,
    this.intakeTypeEntity,
    this.day,
    this.usesImperialUnits, {
    this.browseOnly = false,
  });
}
