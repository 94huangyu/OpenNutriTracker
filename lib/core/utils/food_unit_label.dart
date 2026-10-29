import 'package:opennutritracker/generated/l10n.dart';

/// Display only: keep canonical units unchanged for storage and conversion.
String foodUnitLabel(S s, String? unit) => switch (unit) {
  'serving' => s.servingLabel,
  'gml' || 'g/ml' || null => s.gramMilliliterUnit,
  'g' => s.gramUnit,
  'ml' => s.milliliterUnit,
  'oz' => s.ozUnit,
  'fl.oz' || 'fl oz' => s.flOzUnit,
  _ => unit,
};
