import 'package:flutter/material.dart';

import 'palette.dart';

/// The "Master G" logo mark for in-app use (splash, lock screen, home header).
/// Placeholder: replaced by the real painted logo from the icon work.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: Pal.accent(const Color(0xFF7C5CFF))),
        child: Text('G', style: TextStyle(color: Pal.gold, fontSize: size * 0.55, fontWeight: FontWeight.w900)),
      );
}
