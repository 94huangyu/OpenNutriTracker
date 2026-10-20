import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/usecase/search_products_usecase.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';

class _Search implements SearchProductsUseCase {
  final localQueries = <String>[];
  final queries = <String>[];
  final calls = <Completer<SearchProductsResult>>[];
  Future<SearchProductsResult> search(String query, bool local) async {
    if (local) {
      localQueries.add(query);
      return const SearchProductsResult(
        meals: [],
        remoteStatus: SearchRemoteStatus.notRequested,
      );
    }
    queries.add(query);
    final call = Completer<SearchProductsResult>();
    calls.add(call);
    return call.future;
  }

  @override
  Future<SearchProductsResult> searchOFFProductsByString(
    String query, {
    bool skipRemote = false,
  }) => search(query, skipRemote);
  @override
  Future<SearchProductsResult> searchFDCFoodByString(
    String query, {
    bool skipRemote = false,
    bool forResolution = false,
  }) => search(query, skipRemote);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Config implements GetConfigUsecase {
  @override
  Future<ConfigEntity> getConfig() async =>
      const ConfigEntity(true, true, false, AppThemeEntity.system);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _empty = SearchProductsResult(meals: [], remoteSourceEmpty: true);
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 25));
Future<void> debounce() => Future<void>.delayed(
  searchDebounceDuration + const Duration(milliseconds: 40),
);
void main() {
  for (final food in [false, true]) {
    group(food ? 'FoodBloc' : 'ProductsBloc', () {
      late _Search search;
      late Bloc<dynamic, dynamic> bloc;
      dynamic input(String q) => food
          ? SearchFoodInputChangedEvent(searchString: q)
          : SearchInputChangedEvent(searchString: q);
      dynamic submit(String q) => food
          ? LoadFoodEvent(searchString: q)
          : LoadProductsEvent(searchString: q);
      String? query() => switch (bloc.state) {
        ProductsLoadedState s => s.query,
        FoodLoadedState s => s.query,
        _ => null,
      };
      SearchRemoteStatus? status() => switch (bloc.state) {
        ProductsLoadedState s => s.remoteStatus,
        FoodLoadedState s => s.remoteStatus,
        _ => null,
      };
      setUp(() {
        search = _Search();
        bloc = food
            ? FoodBloc(search, _Config())
            : ProductsBloc(search, _Config());
      });
      tearDown(() async {
        for (final call in search.calls) {
          if (!call.isCompleted) call.complete(_empty);
        }
        await bloc.close();
      });
      test(
        'Chinese single character searches locally immediately, without a remote request',
        () async {
          bloc.add(input('米'));
          await tick();
          expect(search.localQueries, ['米']);
          expect(query(), '米');
          expect(status(), SearchRemoteStatus.notRequested);
          await debounce();
          expect(search.calls, isEmpty);
          bloc.add(submit('米'));
          await tick();
          expect(search.calls, isEmpty);
        },
      );
      test(
        'local state is visible during debounce and a slow remote request',
        () async {
          bloc.add(input('米饭'));
          await tick();
          expect(query(), '米饭');
          expect(status(), SearchRemoteStatus.loading);
          expect(search.calls, isEmpty);
          await debounce();
          expect(search.calls, hasLength(1));
          expect(status(), SearchRemoteStatus.loading);
          search.calls.single.complete(_empty);
          await tick();
          expect(status(), SearchRemoteStatus.empty);
        },
      );
      test(
        'typing cancels a submitted request before the new debounce expires',
        () async {
          bloc.add(submit('apple'));
          await tick();
          bloc.add(input('米饭'));
          await tick();
          search.calls.first.complete(_empty);
          await tick();
          expect(query(), '米饭');
          expect(status(), SearchRemoteStatus.loading);
          await debounce();
          search.calls.last.complete(_empty);
          await tick();
          expect(query(), '米饭');
        },
      );
      test(
        'submit and refresh share cancellation with typing; old result cannot overwrite',
        () async {
          bloc.add(input('apple'));
          await debounce();
          bloc.add(submit('banana'));
          await tick();
          expect(search.calls, hasLength(2));
          search.calls.last.complete(_empty);
          await tick();
          search.calls.first.complete(_empty);
          await tick();
          expect(query(), 'banana');
          bloc.add(
            food ? const RefreshFoodEvent() : const RefreshProductsEvent(),
          );
          await tick();
          expect(search.queries.last, 'banana');
          bloc.add(submit(''));
          await tick();
          search.calls.last.complete(_empty);
          await tick();
          expect(query(), isNull);
        },
      );
      test('failed source is retryable and distinct from empty', () async {
        bloc.add(submit('apple'));
        await tick();
        search.calls.single.complete(
          const SearchProductsResult(
            meals: [],
            remoteStatus: SearchRemoteStatus.failed,
          ),
        );
        await tick();
        expect(status(), SearchRemoteStatus.failed);
        bloc.add(input('apple'));
        await debounce();
        expect(search.calls, hasLength(2));
        search.calls.last.complete(_empty);
        await tick();
        expect(status(), SearchRemoteStatus.empty);
        bloc.add(input('apple'));
        await debounce();
        expect(search.calls, hasLength(2));
      });
      test(
        'blank input cancels even an in-flight local search, and never searches',
        () async {
          bloc.add(submit('apple'));
          await tick();
          bloc.add(input('   '));
          await tick();
          expect(query(), isNull);
          expect(search.localQueries, ['apple']);
          search.calls.single.complete(_empty);
          await tick();
          expect(query(), isNull);
        },
      );
    });
  }
}
