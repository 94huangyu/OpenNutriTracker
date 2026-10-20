part of 'food_bloc.dart';

abstract class FoodState extends Equatable {
  const FoodState();
}

class FoodInitial extends FoodState {
  @override
  List<Object> get props => [];
}

class FoodLoadingState extends FoodState {
  @override
  List<Object?> get props => [];
}

class FoodLoadedState extends FoodState {
  final List<MealEntity> food;
  final bool usesImperialUnits;

  final SearchRemoteStatus remoteStatus;

  /// The raw search input these results answer — see
  /// ProductsLoadedState.query for how the UI uses it.
  final String query;

  const FoodLoadedState({
    required this.food,
    this.usesImperialUnits = false,
    this.remoteStatus = SearchRemoteStatus.results,
    this.query = '',
  });

  @override
  List<Object?> get props =>
      [food, usesImperialUnits, remoteStatus, query];
}

class FoodFailedState extends FoodState {
  @override
  List<Object?> get props => [];
}
