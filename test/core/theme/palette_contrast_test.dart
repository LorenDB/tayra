import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/theme/palette_provider.dart';

/// WCAG 2.x relative luminance, written out independently of the app code.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastOnBlack(Color c) => (_luminance(c) + 0.05) / 0.05;

void main() {
  test('contrast against black follows the WCAG formula', () {
    expect(contrastOnBlack(const Color(0xFFFFFFFF)), closeTo(21.0, 0.01));
    expect(contrastOnBlack(const Color(0xFF000000)), closeTo(1.0, 0.01));
    // Mid grey is 5.32:1 on black; the squared approximation said 6.5:1.
    expect(contrastOnBlack(const Color(0xFF808080)), closeTo(5.32, 0.05));
    for (final color in const [
      Color(0xFF0992F2),
      Color(0xFF00D4AA),
      Color(0xFF7A1F1F),
      Color(0xFF3355AA),
    ]) {
      expect(contrastOnBlack(color), closeTo(_contrastOnBlack(color), 0.001));
    }
  });

  test('lightenForText really reaches the contrast it promises', () {
    for (final dark in const [
      Color(0xFF0000AA), // deep blue: the hardest hue to lift
      Color(0xFF7A1F1F),
      Color(0xFF204020),
      Color(0xFF4B0082),
      Color(0xFF333333),
    ]) {
      final lifted = lightenForText(dark);
      expect(
        _contrastOnBlack(lifted),
        greaterThanOrEqualTo(4.5),
        reason: 'text colour derived from $dark',
      );
      expect(
        _contrastOnBlack(lightenForText(dark, minimumContrast: 7.0)),
        greaterThanOrEqualTo(7.0),
      );
    }
  });

  test('a colour that is already legible is left alone', () {
    const bright = Color(0xFF00D4AA);
    expect(lightenForText(bright), bright);
  });
}
