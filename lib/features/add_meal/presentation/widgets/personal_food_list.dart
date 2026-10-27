import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/personal_food_data_source.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_item_card.dart';
import 'package:opennutritracker/features/add_meal/util/meal_relevance_ranker.dart';
import 'package:opennutritracker/generated/l10n.dart';

class PersonalFoodList extends StatefulWidget {
  final String query;
  final bool favoritesOnly;
  final bool browseOnly;
  final DateTime day;
  final AddMealType addMealType;
  const PersonalFoodList({
    super.key,
    required this.day,
    required this.addMealType,
    this.query = '',
    this.favoritesOnly = false,
    this.browseOnly = false,
  });
  @override
  State<PersonalFoodList> createState() => _PersonalFoodListState();
}

class _PersonalFoodListState extends State<PersonalFoodList> {
  PersonalFoodDataSource? _store;
  @override
  void initState() {
    super.initState();
    if (locator.isRegistered<PersonalFoodDataSource>()) {
      _store = locator<PersonalFoodDataSource>()..addListener(_reload);
    }
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store?.removeListener(_reload);
    super.dispose();
  }

  Future<(List<MealEntity>, bool)> _load() async {
    final meals = await locator<SearchProductsUseCase>().getPersonalMeals(
      widget.query,
      favoritesOnly: widget.favoritesOnly,
    );
    final config = await locator<GetConfigUsecase>().getConfig();
    return (
      mergeAndRankMeals(meals, [], widget.query),
      config.usesImperialFoodUnits,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(List<MealEntity>, bool)>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Semantics(
          identifier: 'personal-food-retry',
          child: TextButton(
            onPressed: _reload,
            child: Text(S.of(context).foodPersonalSaveFailed),
          ),
        );
      }
      final result = snapshot.data;
      if (result == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (result.$1.isEmpty) {
        return Center(child: Text(S.of(context).foodPersonalEmpty));
      }
      return Semantics(
        identifier: 'personal-food-list',
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          itemCount: result.$1.length,
          itemBuilder: (context, i) => MealItemCard(
            day: widget.day,
            addMealType: widget.addMealType,
            mealEntity: result.$1[i],
            usesImperialUnits: result.$2,
            browseOnly: widget.browseOnly,
            onReturn: _reload,
          ),
        ),
      );
    },
  );
}
