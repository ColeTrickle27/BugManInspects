import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

/// The exact, fixed set of colors selectable for markers.
///
/// This is intentionally a short, curated palette (not the app's general
/// text/border/line color palette in `_MarkerColorChoice`), matched to
/// Holloman's report styling. Do not add colors here without a business
/// reason - it is used verbatim in `flex_color_picker`'s
/// `ColorPicker.customColorSwatchesAndNames`.
const Map<String, Color> markerColorPalette = <String, Color>{
  'Red': Color(0xFFCC2000),
  'Purple': Color(0xFF7A068F),
  'Teal': Color(0xFF2B8C93),
  'Indigo': Color(0xFF250899),
  'Light Gray': Color(0xFFB3B3B3),
  'Black': Color(0xFF000000),
  'Gray': Color(0xFF9E9E9E),
  'Olive': Color(0xFFABA957),
};

/// [markerColorPalette] converted to the `Map<ColorSwatch<Object>, String>`
/// shape required by `ColorPicker.customColorSwatchesAndNames`.
final Map<ColorSwatch<Object>, String> markerColorSwatchesAndNames =
    <ColorSwatch<Object>, String>{
  for (final entry in markerColorPalette.entries)
    ColorTools.createPrimarySwatch(entry.value): entry.key,
};
