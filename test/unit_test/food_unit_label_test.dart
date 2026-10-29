import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/food_unit_label.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  test('internal units are readable and custom units stay intact', () {
    final s = lookupS(const Locale('zh'));
    expect(foodUnitLabel(s, 'serving'), '份');
    expect(foodUnitLabel(s, 'gml'), 'g/ml');
    expect(foodUnitLabel(s, null), 'g/ml');
    expect(foodUnitLabel(s, 'fl.oz'), s.flOzUnit);
    expect(foodUnitLabel(s, '瓶'), '瓶');
    expect(foodUnitLabel(s, 'kg'), 'kg');
  });
}
