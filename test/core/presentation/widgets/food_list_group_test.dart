import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/presentation/widgets/food_library_list.dart';

void main() {
  testWidgets(
    'one lazy food group scrolls through a long list and keeps row taps',
    (tester) async {
      var built = 0;
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                FoodListSliver(
                  itemCount: 1000,
                  itemBuilder: (context, index) {
                    built++;
                    return ListTile(
                      title: Text('food $index'),
                      onTap: () => selected = index,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(DecoratedSliver), findsOneWidget);
      expect(built, lessThan(50));
      final rows = find.byType(ListTile);
      final first = tester.getRect(rows.at(0));
      final second = tester.getRect(rows.at(1));
      expect(second.top - first.bottom, 1);
      await tester.scrollUntilVisible(
        find.text('food 100'),
        500,
        maxScrolls: 20,
      );
      await tester.tap(find.text('food 100'));
      expect(selected, 100);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty food group does not draw an empty frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              FoodListSliver(
                itemCount: 0,
                itemBuilder: (_, _) => const Text('unexpected'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(DecoratedSliver), findsNothing);
    expect(find.text('unexpected'), findsNothing);
  });
}
