import 'package:flutter/material.dart';

/// Premium dark palette shared by every screen. Games should use these
/// instead of hard-coded colors so the whole app feels like one product.
class Pal {
  Pal._();
  static const bg0 = Color(0xFF0B0820);
  static const bg1 = Color(0xFF1B1245);
  static const bg2 = Color(0xFF2D1B69);
  static const gold = Color(0xFFFFD369);
  static const goldDeep = Color(0xFFF5A623);
  static const text = Color(0xFFF4F1FF);
  static const textDim = Color(0xFFB9B1E0);
  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFFF6B8A);
  static const glass = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);

  static const accents = <Color>[
    Color(0xFFFF7A59), Color(0xFFFFC857), Color(0xFF4DA8FF), Color(0xFF2EE6A8),
    Color(0xFFB794FF), Color(0xFFFF6FB5), Color(0xFF5EEAD4), Color(0xFFFB923C),
  ];

  static LinearGradient accent(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.black, 0.25)!],
      );
}
