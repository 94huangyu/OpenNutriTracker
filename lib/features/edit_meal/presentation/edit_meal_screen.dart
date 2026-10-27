import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/features/scanner/presentation/widgets/scanner_camera_error.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/user_image_picker_tile.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/barcode_validator.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/core/utils/user_image_draft.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/custom_text_input_formatter.dart';
import 'package:opennutritracker/core/utils/food_name_validator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/navigation_predicates.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import 'package:opennutritracker/features/edit_meal/presentation/widgets/default_meal_image.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class EditMealScreen extends StatefulWidget {
  const EditMealScreen({super.key});

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final log = Logger('EditMealScreen');
  late MealEntity _mealEntity;
  late DateTime _day;
  late IntakeTypeEntity _intakeTypeEntity;
  late bool _usesImperialUnits;

  late bool _editOnly;

  late EditMealBloc _editMealBloc;

  /// Tracks the active form view (#232). Hydrated from ConfigDBO once the
  /// bloc finishes loading, and persisted back whenever the user toggles.
  CustomMealFormMode _formMode = CustomMealFormMode.simple;
  bool _formModeHydrated = false;

  final _nameTextController = TextEditingController();
  final _brandsTextController = TextEditingController();
  final _barcodeTextController = TextEditingController();
  final _mealQuantityTextController = TextEditingController();
  final _servingQuantityTextController = TextEditingController();
  final _baseQuantityTextController = TextEditingController();
  final _kcalTextController = TextEditingController();
  final _carbsTextController = TextEditingController();
  final _fatTextController = TextEditingController();
  final _proteinTextController = TextEditingController();
  // Advanced-mode micronutrient controllers (#232 follow-up: all 10 panel nutrients)
  final _fiberTextController = TextEditingController();
  final _saturatedFatTextController = TextEditingController();
  final _sugarsTextController = TextEditingController();
  final _sodiumTextController = TextEditingController();
  final _calciumTextController = TextEditingController();
  final _ironTextController = TextEditingController();
  final _potassiumTextController = TextEditingController();
  final _magnesiumTextController = TextEditingController();
  final _vitaminDTextController = TextEditingController();
  final _vitaminB12TextController = TextEditingController();
  final _monounsaturatedFatTextController = TextEditingController();
  final _polyunsaturatedFatTextController = TextEditingController();
  final _transFatTextController = TextEditingController();
  final _cholesterolTextController = TextEditingController();
  final _zincTextController = TextEditingController();
  final _phosphorusTextController = TextEditingController();
  final _vitaminATextController = TextEditingController();
  final _vitaminCTextController = TextEditingController();
  final _vitaminB6TextController = TextEditingController();
  final _niacinTextController = TextEditingController();

  final _loadedNutrientTexts = <TextEditingController, String>{};

  final _units = ['g', 'ml', 'g/ml'];
  String? selectedUnit;
  // Default on so behaviour matches what existing users are used to — the
  // meal is saved to their custom list unless they actively untick the box.
  // #249 adds the *option* to skip the save; it does not change the default.
  bool _saveForLater = true;
  bool _saving = false;
  bool get _isPublicFood =>
      _mealEntity.source == MealSourceEntity.off ||
      _mealEntity.source == MealSourceEntity.fdc;

  late List<ButtonSegment<String>> _mealUnitButtonSegment;

  // didChangeDependencies is called on every dependency change, including
  // ones triggered by Navigator pops returning from sub-pages (the barcode
  // scanner among them). Without this guard the controllers would get
  // re-seeded from _mealEntity.code on every return, wiping a value the
  // user just scanned into the field.
  bool _initialised = false;

  bool _energyUsesKj = true;
  double? _canonicalEnergyKcal;
  String _energyDisplayText = '';

  // #64 follow-up: user-attached photo for a custom meal. Mirrors
  // _mealEntity.localImagePath but is held separately so the picker
  // can update the on-screen preview before the parent entity is
  // rebuilt at save time.
  final _draftImages = UserImageDraft(UserImageKind.meal);
  String? _localImagePath;
  bool _localImageCleared = false;

  @override
  void initState() {
    super.initState();
    // Initialize once, not during build.
    _editMealBloc = locator<EditMealBloc>();
    _editMealBloc.add(InitializeEditMealEvent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as EditMealScreenArguments;
    _mealEntity = args.mealEntity;
    _day = args.day;
    _intakeTypeEntity = args.intakeTypeEntity;
    _usesImperialUnits = args.usesImperialUnits;
    _editOnly = args.editOnly;

    _nameTextController.text = _mealEntity.name ?? "";
    _brandsTextController.text = _mealEntity.brands ?? "";
    // MealEntity.code is dual-purpose: it carries a real product barcode for
    // OFF / FDC scans, but for custom meals MealEntity.empty() seeds it with
    // an internal UUID that the user should never see in the Barcode input.
    // Only show codes that actually look like a retail barcode (8–14 digits);
    // anything else means there isn't a user-visible barcode yet.
    final existingCode = _mealEntity.code;
    _barcodeTextController.text =
        (existingCode != null && isBarcodeFormatValid(existingCode))
        ? existingCode
        : "";
    _mealQuantityTextController.text = _mealEntity.mealQuantity ?? "";
    _servingQuantityTextController.text = _mealEntity.servingQuantity == null
        ? ''
        : _formatNumber(_mealEntity.servingQuantity!);
    _baseQuantityTextController.text = _formatNumber(
      _mealEntity.effectiveNutritionBasis,
    );
    final basisFactor = _mealEntity.effectiveNutritionBasis / 100;
    _energyUsesKj = _mealEntity.name == null;
    _canonicalEnergyKcal = _mealEntity.nutriments.energyKcal100 == null
        ? null
        : _mealEntity.nutriments.energyKcal100! * basisFactor;
    _kcalTextController.text = _formatStoredKcalForDisplay(
      _mealEntity.nutriments.energyKcal100 == null
          ? null
          : _mealEntity.nutriments.energyKcal100! * basisFactor,
      _energyUsesKj,
    );
    _energyDisplayText = _kcalTextController.text;
    final n = _mealEntity.nutriments;
    for (final entry in <TextEditingController, double?>{
      _carbsTextController: n.carbohydrates100,
      _fatTextController: n.fat100,
      _proteinTextController: n.proteins100,
      _fiberTextController: n.fiber100,
      _saturatedFatTextController: n.saturatedFat100,
      _sugarsTextController: n.sugars100,
      _sodiumTextController: n.sodium100,
      _calciumTextController: n.calcium100,
      _ironTextController: n.iron100,
      _potassiumTextController: n.potassium100,
      _magnesiumTextController: n.magnesium100,
      _vitaminDTextController: n.vitaminD100,
      _vitaminB12TextController: n.vitaminB12100,
      _monounsaturatedFatTextController: n.monounsaturatedFat100,
      _polyunsaturatedFatTextController: n.polyunsaturatedFat100,
      _transFatTextController: n.transFat100,
      _cholesterolTextController: n.cholesterol100,
      _zincTextController: n.zinc100,
      _phosphorusTextController: n.phosphorus100,
      _vitaminATextController: n.vitaminA100,
      _vitaminCTextController: n.vitaminC100,
      _vitaminB6TextController: n.vitaminB6100,
      _niacinTextController: n.niacin100,
    }.entries) {
      entry.key.text = entry.value == null
          ? ''
          : _formatNumber(entry.value! * basisFactor);
      _loadedNutrientTexts[entry.key] = entry.key.text;
    }
    _localImagePath = _mealEntity.localImagePath;
    selectedUnit = _switchButtonUnit(_mealEntity.mealUnit);

    _mealUnitButtonSegment = [
      ButtonSegment(value: _units[0], label: Text(S.of(context).gramUnit)),
      ButtonSegment(
        value: _units[1],
        label: Text(S.of(context).milliliterUnit),
      ),
      if (selectedUnit == _units[2])
        ButtonSegment(
          value: _units[2],
          label: Text(S.of(context).gramMilliliterUnit),
        ),
    ];
  }

  @override
  void dispose() {
    _nameTextController.dispose();
    _brandsTextController.dispose();
    _barcodeTextController.dispose();
    _mealQuantityTextController.dispose();
    _servingQuantityTextController.dispose();
    _baseQuantityTextController.dispose();
    _kcalTextController.dispose();
    _carbsTextController.dispose();
    _fatTextController.dispose();
    _proteinTextController.dispose();
    for (final controller in [
      _fiberTextController,
      _saturatedFatTextController,
      _sugarsTextController,
      _sodiumTextController,
      _calciumTextController,
      _ironTextController,
      _potassiumTextController,
      _magnesiumTextController,
      _vitaminDTextController,
      _vitaminB12TextController,
      _monounsaturatedFatTextController,
      _polyunsaturatedFatTextController,
      _transFatTextController,
      _cholesterolTextController,
      _zincTextController,
      _phosphorusTextController,
      _vitaminATextController,
      _vitaminCTextController,
      _vitaminB6TextController,
      _niacinTextController,
    ]) {
      controller.dispose();
    }
    unawaited(_draftImages.dispose());
    _editMealBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(
          backgroundColor: palette.canvas,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: MediaQuery.textScalerOf(context).scale(kToolbarHeight),
          title: AutoSizeText(
            _mealEntity.name == null
                ? S.of(context).noResultsCreateCustomFood
                : S.of(context).editMealLabel,
            minFontSize: 16,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: AbsorbPointer(
            absorbing: _saving,
            child: BlocBuilder<EditMealBloc, EditMealState>(
              bloc: _editMealBloc,
              builder: (BuildContext context, EditMealState state) {
                if (state is EditMealLoadingState) return _getLoadingContent();
                if (state is EditMealLoadedState) {
                  if (!_formModeHydrated) {
                    _formMode = state.formMode;
                    _formModeHydrated = true;
                  }
                  return _getLoadedContent(_energyUsesKj);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Semantics(
              identifier: 'edit-meal-save',
              child: FilledButton(
                onPressed: _saving
                    ? null
                    : () => _onSavePressed(_usesImperialUnits),
                child: Text(S.of(context).buttonSaveLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double? _readEnergyKcal() {
    if (_kcalTextController.text == _energyDisplayText) {
      return _canonicalEnergyKcal;
    }
    final value = double.tryParse(_kcalTextController.text);
    return value == null
        ? null
        : _energyUsesKj
        ? UnitCalc.kjToKcal(value)
        : value;
  }

  void _switchEnergyUnit(bool? usesKj) {
    if (usesKj == null || usesKj == _energyUsesKj) return;
    final kcal = _readEnergyKcal();
    if (_kcalTextController.text.trim().isNotEmpty &&
        (kcal == null || !kcal.isFinite || kcal < 0)) {
      return;
    }
    setState(() {
      _canonicalEnergyKcal = kcal;
      _energyUsesKj = usesKj;
      _kcalTextController.text = _formatStoredKcalForDisplay(kcal, usesKj);
      _energyDisplayText = _kcalTextController.text;
    });
  }

  /// Convert a stored kcal value into the string the user should see in
  /// the energy field, given the active unit. Storage remains kcal.
  String _formatStoredKcalForDisplay(double? storedKcal, bool usesKj) {
    if (storedKcal == null) return "";
    final display = usesKj ? UnitCalc.kcalToKj(storedKcal) : storedKcal;
    return _formatNumber(display);
  }

  Widget _getLoadingContent() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _getLoadedContent(bool usesKj) {
    final isSimple = _formMode == CustomMealFormMode.simple;
    final energyUnitSuffix = usesKj
        ? S.of(context).kjLabel
        : S.of(context).kcalLabel;
    final unitSuffix = _massUnitSuffix(context);
    final perQtyHelper = S
        .of(context)
        .mealNutrientsPerQtyLabel(_getDisplayQuantity(), unitSuffix);
    final energyHelper = perQtyHelper;
    final macroHelper = perQtyHelper;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Custom meals get the same picker tile recipes use — a single
        // tappable circle with an overlay camera icon, "Add a photo"
        // text beneath, and a bottom-sheet for the action choice.
        // OFF / FDC entries keep the existing remote-image avatar:
        // they cannot have a user-attached photo, so showing the
        // picker affordance would be misleading.
        if (_mealEntity.source == MealSourceEntity.custom)
          Center(
            child: UserImagePickerTile(
              kind: UserImageKind.meal,
              imagePath: _localImagePath,
              onPickFromGallery: () => _onPickMealImage(ImageSource.gallery),
              onTakePhoto: () => _onPickMealImage(ImageSource.camera),
              onRemove: _onRemoveMealImage,
            ),
          )
        else
          Center(child: _buildRemoteMealImage()),
        const SizedBox(height: 24),
        // Both modes use the same package, serving and label basis.
        // Advanced only reveals additional nutrient inputs.
        Text(
          S.of(context).customMealFormModeLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'edit-meal-mode-toggle',
          child: SegmentedButton<CustomMealFormMode>(
            segments: [
              ButtonSegment(
                value: CustomMealFormMode.simple,
                label: Text(S.of(context).customMealFormSimple),
              ),
              ButtonSegment(
                value: CustomMealFormMode.advanced,
                label: Text(S.of(context).customMealFormAdvanced),
              ),
            ],
            selected: {_formMode},
            onSelectionChanged: (Set<CustomMealFormMode> selection) {
              final newMode = selection.first;
              setState(() {
                _formMode = newMode;
              });
              _editMealBloc.setFormMode(newMode);
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isSimple
              ? S.of(context).customMealFormSimpleHelp
              : S.of(context).customMealFormAdvancedHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _section(S.of(context).foodBasicInformation, [
          Semantics(
            identifier: 'edit-meal-name',
            child: TextFormField(
              controller: _nameTextController,
              decoration: InputDecoration(
                labelText: S.of(context).mealNameLabel,
                border: const OutlineInputBorder(
                  borderRadius: Dimens.borderRadiusM,
                ),
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'edit-meal-brand',
            child: TextFormField(
              controller: _brandsTextController,
              decoration: InputDecoration(
                labelText: S.of(context).mealBrandsLabel,
                border: const OutlineInputBorder(
                  borderRadius: Dimens.borderRadiusM,
                ),
              ),
              keyboardType: TextInputType.text,
            ),
          ),
          const SizedBox(height: 16),
          // Optional barcode (#167). Lets the user attach a code to a custom
          // meal so a future scan recalls the saved version directly without
          // round-tripping through Open Food Facts.
          Semantics(
            identifier: 'edit-meal-barcode-input',
            child: TextFormField(
              controller: _barcodeTextController,
              decoration: InputDecoration(
                labelText: S.of(context).customMealBarcodeLabel,
                hintText: S.of(context).customMealBarcodeHint,
                border: const OutlineInputBorder(
                  borderRadius: Dimens.borderRadiusM,
                ),
                suffixIcon: Semantics(
                  identifier: 'edit-meal-barcode-scan',
                  child: IconButton(
                    tooltip: S.of(context).customMealBarcodeScanButton,
                    icon: const Icon(Icons.barcode_reader),
                    onPressed: _scanBarcodeIntoField,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ]),
        _section(S.of(context).foodSpecifications, [
          Semantics(
            identifier: 'edit-meal-unit-selector',
            child: SegmentedButton<String>(
              segments: _mealUnitButtonSegment,
              selected: {selectedUnit ?? _units[0]},
              onSelectionChanged: (selection) => setState(() {
                selectedUnit = selection.first;
              }),
            ),
          ),
          const SizedBox(height: 20),
          _responsiveFields([
            _buildQuantityField(
              _mealQuantityTextController,
              S.of(context).mealSizeLabel,
              unitSuffix,
              'edit-meal-package-quantity',
            ),
            _buildQuantityField(
              _servingQuantityTextController,
              S.of(context).servingSizeLabelMetric,
              unitSuffix,
              'edit-meal-serving-quantity',
            ),
          ]),
        ]),
        _section(S.of(context).nutritionInfoLabel, [
          _buildQuantityField(
            _baseQuantityTextController,
            S.of(context).baseQuantityLabel,
            unitSuffix,
            'edit-meal-nutrition-basis',
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).customMealBasisHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _responsiveFields([
            Semantics(
              identifier: 'edit-meal-energy',
              child: TextFormField(
                controller: _kcalTextController,
                onChanged: (_) => setState(() {
                  _canonicalEnergyKcal = _readEnergyKcal();
                  _energyDisplayText = _kcalTextController.text;
                }),
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                  labelText:
                      '${S.of(context).mealEnergyLabel} ($energyUnitSuffix)',
                  helperText: energyHelper,
                  border: const OutlineInputBorder(
                    borderRadius: Dimens.borderRadiusM,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            Semantics(
              identifier: 'edit-meal-energy-unit',
              child: DropdownButtonFormField<bool>(
                initialValue: _energyUsesKj,
                key: ValueKey(_energyUsesKj),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: S.of(context).energyInputUnit,
                  border: const OutlineInputBorder(
                    borderRadius: Dimens.borderRadiusM,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('kJ')),
                  DropdownMenuItem(value: false, child: Text('kcal')),
                ],
                onChanged: _switchEnergyUnit,
              ),
            ),
          ], compactUnit: true),
          const SizedBox(height: 8),
          if (_readEnergyKcal() case final kcal?
              when kcal.isFinite && kcal >= 0)
            Text(
              '≈ ${(_energyUsesKj ? kcal : UnitCalc.kcalToKj(kcal)).toStringAsFixed(1)} '
              '${_energyUsesKj ? 'kcal' : 'kJ'} · $perQtyHelper',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          Text(
            S.of(context).energyInputHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _responsiveFields([
            Semantics(
              identifier: 'edit-meal-carbs',
              child: TextFormField(
                controller: _carbsTextController,
                onChanged: (_) => setState(() {}),
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                  labelText: S.of(context).mealCarbsLabel,
                  suffixText: 'g',
                  helperText: macroHelper,
                  border: const OutlineInputBorder(
                    borderRadius: Dimens.borderRadiusM,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            Semantics(
              identifier: 'edit-meal-fat',
              child: TextFormField(
                controller: _fatTextController,
                onChanged: (_) => setState(() {}),
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                  labelText: S.of(context).mealFatLabel,
                  suffixText: 'g',
                  helperText: macroHelper,
                  border: const OutlineInputBorder(
                    borderRadius: Dimens.borderRadiusM,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            Semantics(
              identifier: 'edit-meal-protein',
              child: TextFormField(
                controller: _proteinTextController,
                onChanged: (_) => setState(() {}),
                inputFormatters: CustomTextInputFormatter.doubleOnly(),
                decoration: InputDecoration(
                  labelText: S.of(context).mealProteinLabel,
                  suffixText: 'g',
                  helperText: macroHelper,
                  border: const OutlineInputBorder(
                    borderRadius: Dimens.borderRadiusM,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            S.of(context).customMealUnknownNutrientsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (labelEnergyNeedsReview(
            kcal: _readEnergyKcal(),
            carbs: double.tryParse(_carbsTextController.text),
            fat: double.tryParse(_fatTextController.text),
            protein: double.tryParse(_proteinTextController.text),
            fiber: double.tryParse(_fiberTextController.text),
          ))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                S.of(context).customMealNutrientDifferenceHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (labelCompositionNeedsReview(
            carbs: double.tryParse(_carbsTextController.text),
            fat: double.tryParse(_fatTextController.text),
            protein: double.tryParse(_proteinTextController.text),
            sugars: double.tryParse(_sugarsTextController.text),
            saturatedFat: double.tryParse(_saturatedFatTextController.text),
            basis: double.tryParse(_baseQuantityTextController.text) ?? 0,
            isLiquid: selectedUnit == 'ml',
          ))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                S.of(context).foodCompositionReviewHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (!isSimple) ...[
            const SizedBox(height: 32),
            Text(
              S.of(context).micronutrientsLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final field in [
              (_fiberTextController, S.of(context).fiberLabel, 'g', 'fiber'),
              (
                _saturatedFatTextController,
                S.of(context).saturatedFatLabel,
                'g',
                'saturated-fat',
              ),
              (_sugarsTextController, S.of(context).sugarLabel, 'g', 'sugars'),
              (
                _sodiumTextController,
                S.of(context).sodiumLabel,
                'mg',
                'sodium',
              ),
              (
                _calciumTextController,
                S.of(context).calciumLabel,
                'mg',
                'calcium',
              ),
              (_ironTextController, S.of(context).ironLabel, 'mg', 'iron'),
              (
                _potassiumTextController,
                S.of(context).potassiumLabel,
                'mg',
                'potassium',
              ),
              (
                _magnesiumTextController,
                S.of(context).magnesiumLabel,
                'mg',
                'magnesium',
              ),
              (
                _vitaminDTextController,
                S.of(context).vitaminDLabel,
                'µg',
                'vitamin-d',
              ),
              (
                _vitaminB12TextController,
                S.of(context).vitaminB12Label,
                'µg',
                'vitamin-b12',
              ),
              (
                _monounsaturatedFatTextController,
                S.of(context).monounsaturatedFatLabel,
                'g',
                'monounsaturated-fat',
              ),
              (
                _polyunsaturatedFatTextController,
                S.of(context).polyunsaturatedFatLabel,
                'g',
                'polyunsaturated-fat',
              ),
              (
                _transFatTextController,
                S.of(context).transFatLabel,
                'g',
                'trans-fat',
              ),
              (
                _cholesterolTextController,
                S.of(context).cholesterolLabel,
                'mg',
                'cholesterol',
              ),
              (_zincTextController, S.of(context).zincLabel, 'mg', 'zinc'),
              (
                _phosphorusTextController,
                S.of(context).phosphorusLabel,
                'mg',
                'phosphorus',
              ),
              (
                _vitaminATextController,
                S.of(context).vitaminALabel,
                'µg',
                'vitamin-a',
              ),
              (
                _vitaminCTextController,
                S.of(context).vitaminCLabel,
                'mg',
                'vitamin-c',
              ),
              (
                _vitaminB6TextController,
                S.of(context).vitaminB6Label,
                'mg',
                'vitamin-b6',
              ),
              (
                _niacinTextController,
                S.of(context).niacinLabel,
                'mg',
                'niacin',
              ),
            ]) ...[
              Semantics(
                identifier: 'edit-meal-${field.$4}',
                child: _buildMicroField(
                  field.$1,
                  field.$2,
                  field.$3,
                  perQtyHelper,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ]),
        if (_isPublicFood) ...[
          const SizedBox(height: 16),
          Text(S.of(context).customMealCopyHint),
        ],
        if (!_editOnly && !_isPublicFood) ...[
          const SizedBox(height: 24),
          _SaveForLaterField(
            value: _saveForLater,
            onChanged: (newValue) {
              setState(() {
                _saveForLater = newValue;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        AppCard(
          shadowed: false,
          borderRadius: 16,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );

  Widget _responsiveFields(List<Widget> children, {bool compactUnit = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 280 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18
              ? 2
              : 1;
          if (compactUnit && columns == 2) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: children[0]),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: children[1]),
              ],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                  child: child,
                ),
            ],
          );
        },
      );

  Widget _buildMicroField(
    TextEditingController controller,
    String label,
    String unit,
    String? helperText,
  ) {
    return TextFormField(
      controller: controller,
      inputFormatters: CustomTextInputFormatter.doubleOnly(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        helperText: helperText,
        border: const OutlineInputBorder(borderRadius: Dimens.borderRadiusM),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  String _formatNumber(double value) => double.parse(
    value.toStringAsPrecision(12),
  ).toString().replaceFirst(RegExp(r'\.0$'), '');

  String _getDisplayQuantity() => _baseQuantityTextController.text.isEmpty
      ? '—'
      : _baseQuantityTextController.text;

  // Package labels use metric quantities regardless of intake display units.
  String _massUnitSuffix(BuildContext context) => switch (selectedUnit) {
    'g' => S.of(context).gramUnit,
    'ml' => S.of(context).milliliterUnit,
    _ => S.of(context).gramMilliliterUnit,
  };

  Widget _buildQuantityField(
    TextEditingController controller,
    String label,
    String unit,
    String identifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Semantics(
          identifier: identifier,
          child: TextFormField(
            controller: controller,
            inputFormatters: CustomTextInputFormatter.doubleOnly(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              suffixText: unit,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              border: const OutlineInputBorder(
                borderRadius: Dimens.borderRadiusM,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }

  // Hidden, untouched values retain their canonical per-100 data even if
  // the visible label basis changes. Edits made in Advanced survive hiding.
  String? _microTextForSave(TextEditingController controller) =>
      _formMode == CustomMealFormMode.simple &&
          controller.text == _loadedNutrientTexts[controller]
      ? null
      : controller.text;

  Future<void> _onSavePressed(bool usesImperialUnits) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Validate meal name: non-empty and contains at least one letter (#211, #214)
      if (!FoodNameValidator.isValid(_nameTextController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).mealNameValidationError)),
        );
        return;
      }

      // Validate barcode shape if the user typed or scanned one (#167).
      // Empty is fine — the field is optional. 8-14 digits required;
      // EAN-13 check digit must verify for codes of that exact length.
      final rawBarcode = _barcodeTextController.text.trim();
      if (rawBarcode.isNotEmpty) {
        if (!isBarcodeFormatValid(rawBarcode)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).customMealBarcodeInvalid)),
          );
          return;
        }
        if (!isEan13CheckDigitValid(rawBarcode)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).barcodeInvalidEan13CheckDigit),
            ),
          );
          return;
        }
      }

      for (final entry in <String, TextEditingController>{
        S.of(context).mealSizeLabel: _mealQuantityTextController,
        S.of(context).servingSizeLabelMetric: _servingQuantityTextController,
        S.of(context).baseQuantityLabel: _baseQuantityTextController,
      }.entries) {
        final text = entry.value.text.trim();
        if (text.isEmpty && entry.value != _baseQuantityTextController) {
          continue;
        }
        final value = double.tryParse(text);
        if (value == null || !value.isFinite || value <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).customMealQuantityInvalid(entry.key)),
            ),
          );
          return;
        }
      }
      final nutrientControllers = [
        _kcalTextController,
        _carbsTextController,
        _fatTextController,
        _proteinTextController,
        _fiberTextController,
        _saturatedFatTextController,
        _sugarsTextController,
        _sodiumTextController,
        _calciumTextController,
        _ironTextController,
        _potassiumTextController,
        _magnesiumTextController,
        _vitaminDTextController,
        _vitaminB12TextController,
        _monounsaturatedFatTextController,
        _polyunsaturatedFatTextController,
        _transFatTextController,
        _cholesterolTextController,
        _zincTextController,
        _phosphorusTextController,
        _vitaminATextController,
        _vitaminCTextController,
        _vitaminB6TextController,
        _niacinTextController,
      ];
      for (final controller in nutrientControllers) {
        if (controller.text.trim().isEmpty) continue;
        final value = double.tryParse(controller.text);
        if (value == null || !value.isFinite || value < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).customMealNutrientInvalid)),
          );
          return;
        }
      }
      final kcal = _readEnergyKcal();
      final newMealEntity = _editMealBloc.createNewMealEntity(
        _mealEntity,
        _nameTextController.text,
        _brandsTextController.text,
        _mealQuantityTextController.text,
        _servingQuantityTextController.text,
        _baseQuantityTextController.text,
        selectedUnit,
        kcal?.toString() ?? '',
        _carbsTextController.text,
        _fatTextController.text,
        _proteinTextController.text,
        fiberText: _microTextForSave(_fiberTextController),
        saturatedFatText: _microTextForSave(_saturatedFatTextController),
        sugarsText: _microTextForSave(_sugarsTextController),
        sodiumText: _microTextForSave(_sodiumTextController),
        calciumText: _microTextForSave(_calciumTextController),
        ironText: _microTextForSave(_ironTextController),
        potassiumText: _microTextForSave(_potassiumTextController),
        magnesiumText: _microTextForSave(_magnesiumTextController),
        vitaminDText: _microTextForSave(_vitaminDTextController),
        vitaminB12Text: _microTextForSave(_vitaminB12TextController),
        monounsaturatedFatText: _microTextForSave(
          _monounsaturatedFatTextController,
        ),
        polyunsaturatedFatText: _microTextForSave(
          _polyunsaturatedFatTextController,
        ),
        transFatText: _microTextForSave(_transFatTextController),
        cholesterolText: _microTextForSave(_cholesterolTextController),
        zincText: _microTextForSave(_zincTextController),
        phosphorusText: _microTextForSave(_phosphorusTextController),
        vitaminAText: _microTextForSave(_vitaminATextController),
        vitaminCText: _microTextForSave(_vitaminCTextController),
        vitaminB6Text: _microTextForSave(_vitaminB6TextController),
        niacinText: _microTextForSave(_niacinTextController),

        barcodeOverride: rawBarcode.isEmpty
            ? (isBarcodeFormatValid(_mealEntity.code ?? '') ? '' : null)
            : rawBarcode,
        localImagePathOverride: _localImagePath,
        clearLocalImagePath: _localImageCleared && _localImagePath == null,
        asPersonalCopy: _isPublicFood,
      );

      // Persist custom meal template (#267). Skipped for one-off entries
      // (#249) when the user has turned off "Save for next time" — the
      // intake itself is still logged below, but no template is kept.
      final shouldPersistTemplate = _isPublicFood || _editOnly || _saveForLater;
      if (newMealEntity.source == MealSourceEntity.custom &&
          shouldPersistTemplate) {
        final saved = await _editMealBloc.saveCustomMeal(
          newMealEntity,
          original: _mealEntity.source == MealSourceEntity.custom
              ? _mealEntity
              : null,
        );
        if (!saved) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).customMealBarcodeInUse)),
          );
          return;
        }
      }

      _draftImages.retain(newMealEntity.localImagePath);
      if (!mounted) return;
      if (_editOnly) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          NavigationOptions.mealDetailRoute,
          namedRouteOrFirst(NavigationOptions.addMealRoute),
          arguments: MealDetailScreenArguments(
            newMealEntity,
            _intakeTypeEntity,
            _day,
            usesImperialUnits,
          ),
        );
      }
    } catch (exception, stacktrace) {
      log.warning("Error while creating new meal entity");
      Sentry.captureException(exception, stackTrace: stacktrace);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).errorMealSave)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Push a lightweight `MobileScanner` page that returns the first product
  /// barcode it sees, then drop the value into the barcode TextField. The
  /// scan-time validator on the field handles bad codes (8–14 digits,
  /// EAN-13 check digit) — we don't double-validate here so the user can
  /// see and edit the raw scanned value before saving.
  Future<void> _scanBarcodeIntoField() async {
    log.fine('Opening edit-meal barcode scanner');
    final navigator = Navigator.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await navigator.push<String?>(
      MaterialPageRoute(builder: (_) => const _EditMealBarcodeScanPage()),
    );
    log.fine('Edit-meal barcode scanner returned: $result');
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _barcodeTextController.text = result;
    });
    log.fine(
      'Barcode text controller after set: ${_barcodeTextController.text}',
    );
  }

  Widget _buildRemoteMealImage() {
    if (_mealEntity.mainImageUrl?.isNotEmpty != true) {
      return const DefaultMealImage();
    }
    return ClipOval(
      child: CachedNetworkImage(
        cacheManager: locator<CacheManager>(),
        width: 120,
        height: 120,
        placeholder: (context, string) => const DefaultMealImage(),
        errorWidget: (context, exception, stacktrace) =>
            const DefaultMealImage(),
        fit: BoxFit.cover,
        imageUrl: _mealEntity.mainImageUrl ?? "",
      ),
    );
  }

  Future<void> _onPickMealImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;
      final relative = await _draftImages.importFrom(picked.path);
      if (relative == null || !mounted) return;
      setState(() {
        _localImagePath = relative;
        _localImageCleared = false;
      });
    } catch (e, st) {
      // Pick / encode failure is rare; surfacing a SnackBar from inside
      // the picker flow felt noisier than the failure deserves. The user
      // can simply tap the picker again.
      log.warning('Failed to pick meal image', e, st);
    }
  }

  Future<void> _onRemoveMealImage() async {
    final current = _localImagePath;
    if (current == null) return;
    if (!mounted) return;
    setState(() {
      _localImagePath = null;
      _localImageCleared = true;
    });
  }

  String? _switchButtonUnit(String? unit) {
    if (!_units.contains(unit)) {
      return _mealEntity.name == null ? _units[0] : _units[2];
    }
    return unit;
  }
}

class EditMealScreenArguments {
  final DateTime day;
  final MealEntity mealEntity;
  final IntakeTypeEntity intakeTypeEntity;
  final bool usesImperialUnits;
  final bool editOnly;

  EditMealScreenArguments(
    this.day,
    this.mealEntity,
    this.intakeTypeEntity,
    this.usesImperialUnits, {
    this.editOnly = false,
  });
}

/// "Save for next time" toggle shown on the create-and-log path (#249).
/// Defaults to on so a newly created food stays searchable next time.
/// The user can opt out for a one-off entry.
class _SaveForLaterField extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SaveForLaterField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    return AppCard(
      color: palette.surfaceMuted,
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacing8,
        Dimens.spacing12,
        Dimens.spacing16,
        Dimens.spacing12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'edit-meal-save-for-later',
            child: Checkbox(
              value: value,
              onChanged: (newValue) => onChanged(newValue ?? false),
            ),
          ),
          const SizedBox(width: Dimens.spacing4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Dimens.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.recipeSaveForLaterLabel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Dimens.spacing4),
                  Text(
                    s.recipeSaveForLaterDescription,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal camera page used by [_EditMealScreenState._scanBarcodeIntoField].
/// Pops itself with the first product barcode it detects, or returns null
/// when the user taps the back button. We keep this private to the edit-meal
/// flow rather than reusing the full ScannerScreen because that screen runs
/// its own lookup-and-route logic that wouldn't fit a "give me the raw
/// string" use case.
class _EditMealBarcodeScanPage extends StatefulWidget {
  const _EditMealBarcodeScanPage();

  @override
  State<_EditMealBarcodeScanPage> createState() =>
      _EditMealBarcodeScanPageState();
}

class _EditMealBarcodeScanPageState extends State<_EditMealBarcodeScanPage>
    with WidgetsBindingObserver {
  static final _log = Logger('EditMealBarcodeScan');
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_controller.stop());
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    _log.fine(
      'onDetect: ${capture.barcodes.length} barcodes; '
      'types=${capture.barcodes.map((b) => b.type.name).toList()}; '
      'rawValues=${capture.barcodes.map((b) => b.rawValue).toList()}',
    );
    if (_done) return;
    for (final b in capture.barcodes) {
      // Accept any non-null raw value. ML Kit's type classifier is reliable
      // for QR / data-matrix but sometimes labels a valid retail barcode as
      // `BarcodeType.unknown` depending on print quality and camera angle —
      // filtering strictly by `BarcodeType.product` was silently dropping
      // those. The save-time validator on the edit-meal screen does the
      // real "is this a valid barcode" check.
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _log.fine('Popping with rawValue=$raw (type=${b.type.name})');
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).customMealBarcodeScanButton)),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) =>
            ScannerCameraError(error: error, onRetry: _controller.start),
      ),
    );
  }
}
