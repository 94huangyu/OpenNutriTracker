import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';

part 'food_event.dart';
part 'food_state.dart';

class FoodBloc extends Bloc<FoodEvent, FoodState> {
  final log = Logger('FoodBloc');
  final SearchProductsUseCase _searchProductUseCase;
  final GetConfigUsecase _getConfigUsecase;
  String _searchString = '';
  String? _completedQuery;

  FoodBloc(this._searchProductUseCase, this._getConfigUsecase)
    : super(FoodInitial()) {
    on<FoodEvent>((event, emit) async {
      final query = switch (event) {
        LoadFoodEvent() => event.searchString,
        SearchFoodInputChangedEvent() => event.searchString,
        _ => _searchString,
      };
      final force = event is! SearchFoodInputChangedEvent;
      if (!force && query == _completedQuery) return;
      _searchString = query;
      _completedQuery = null;
      if (query.trim().isEmpty) {
        emit(FoodInitial());
        return;
      }
      final remote = query.trim().length >= minQueryLength;
      emit(FoodLoadingState());
      try {
        final config = await _getConfigUsecase.getConfig();
        final local = await _searchProductUseCase.searchFDCFoodByString(
          query,
          skipRemote: true,
        );
        if (emit.isDone) return;
        emit(
          FoodLoadedState(
            food: local.meals,
            usesImperialUnits: config.usesImperialFoodUnits,
            remoteStatus: remote
                ? SearchRemoteStatus.loading
                : SearchRemoteStatus.notRequested,
            query: query,
          ),
        );
        if (remote) {
          if (!force) await Future<void>.delayed(searchDebounceDuration);
          if (emit.isDone) return;
          final result = await _searchProductUseCase.searchFDCFoodByString(
            query,
          );
          if (emit.isDone) return;
          emit(
            FoodLoadedState(
              food: result.meals,
              usesImperialUnits: config.usesImperialFoodUnits,
              remoteStatus: result.remoteStatus,
              query: query,
            ),
          );
          // Retyping a failed query is a retry, not a completed-query no-op.
          if (result.remoteStatus == SearchRemoteStatus.failed) return;
        }
        _completedQuery = query;
      } catch (error) {
        log.severe(error);
        if (!emit.isDone) emit(FoodFailedState());
      }
    }, transformer: restartable());
  }
}
