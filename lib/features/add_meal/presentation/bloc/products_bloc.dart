import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';

part 'products_event.dart';
part 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final log = Logger('ProductsBloc');
  final SearchProductsUseCase _searchProductUseCase;
  final GetConfigUsecase _getConfigUsecase;
  String _searchString = '';
  String? _completedQuery;

  ProductsBloc(this._searchProductUseCase, this._getConfigUsecase)
    : super(ProductsInitial()) {
    on<ProductsEvent>((event, emit) async {
      final query = switch (event) {
        LoadProductsEvent() => event.searchString,
        SearchInputChangedEvent() => event.searchString,
        _ => _searchString,
      };
      final force = event is! SearchInputChangedEvent;
      if (!force && query == _completedQuery) return;
      _searchString = query;
      _completedQuery = null;
      if (query.trim().isEmpty) {
        emit(ProductsInitial());
        return;
      }
      final remote = query.trim().length >= minQueryLength;
      emit(ProductsLoadingState());
      try {
        final config = await _getConfigUsecase.getConfig();
        final local = await _searchProductUseCase.searchOFFProductsByString(
          query,
          skipRemote: true,
        );
        if (emit.isDone) return;
        emit(
          ProductsLoadedState(
            products: local.meals,
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
          final result = await _searchProductUseCase.searchOFFProductsByString(
            query,
          );
          if (emit.isDone) return;
          emit(
            ProductsLoadedState(
              products: result.meals,
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
        if (!emit.isDone) emit(ProductsFailedState());
      }
    }, transformer: restartable());
  }
}
