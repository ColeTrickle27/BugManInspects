// Regression coverage for item 6: the marker color picker must expose
// exactly the approved 8-color palette (and only that palette) as
// flex_color_picker custom swatches.
import 'package:bugman_graphs/models/marker_color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marker palette contains exactly the 8 approved hex colors', () {
    const approvedHex = <int>{
      0xFFCC2000,
      0xFF7A068F,
      0xFF2B8C93,
      0xFF250899,
      0xFFB3B3B3,
      0xFF000000,
      0xFF9E9E9E,
      0xFFABA957,
    };

    expect(markerColorPalette.length, 8);
    final actualHex =
        markerColorPalette.values.map((color) => color.toARGB32()).toSet();
    expect(actualHex, approvedHex);

    // Every color must have a sensible (non-empty, non-generic) name.
    for (final name in markerColorPalette.keys) {
      expect(name, isNotEmpty);
      expect(name.toLowerCase(), isNot('custom'));
    }
  });

  test('marker swatches-and-names map matches the palette 1:1', () {
    expect(markerColorSwatchesAndNames.length, markerColorPalette.length);
    final swatchHex = markerColorSwatchesAndNames.keys
        .map((swatch) => (swatch as Color).toARGB32())
        .toSet();
    final paletteHex =
        markerColorPalette.values.map((color) => color.toARGB32()).toSet();
    expect(swatchHex, paletteHex);
  });
}
