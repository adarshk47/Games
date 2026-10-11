import 'package:flutter/material.dart';

/// Colours of Indian festivals and traditional attire, shared by the festive
/// background and the festive home layout.
class Festive {
  Festive._();
  static const marigold = Color(0xFFFF9F1C);
  static const marigoldDeep = Color(0xFFE8590C);
  static const kumkum = Color(0xFFC8102E);
  static const sindoor = Color(0xFF8E0E1C);
  static const haldi = Color(0xFFFFC93C);
  static const peacock = Color(0xFF0F8A84);
  static const peacockBlue = Color(0xFF1F5FB2);
  static const leaf = Color(0xFF2E8B3A);
  static const leafDark = Color(0xFF1B5E20);
  static const zari = Color(0xFFD4AF37);
  static const zariLight = Color(0xFFFFE08A);
  static const flame = Color(0xFFFFB347);

  static const zariGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [zariLight, zari, Color(0xFF9C7A1E), zari, zariLight],
  );

  /// Rangoli powder colours, cycled by motif painters.
  static const rangoli = <Color>[kumkum, haldi, peacock, marigold, Color(0xFFB04BD6), leaf];
}
