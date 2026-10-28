import 'package:flutter/material.dart';

import '../core/release_stage.dart';
import '../core/i18n/i18n.dart';
import '../core/ui/app_theme.dart';
import '../core/ui/ui.dart';

/// Home-screen touches that follow the active theme's decoration: a frame
/// around game cards and a greeting banner under the header.
class ThemeStyle {
  ThemeStyle._();

  /// No themed frames / greetings in 2.5.0 (stage 1).
  static String? get decor => kStage >= 2 ? AppThemeController.theme.decor : null;

  /// Wraps a game card in the theme's frame (neon glow, frost, gold …).
  static Widget frame(Widget child, {double radius = 22}) {
    final (border, glow) = switch (decor) {
      'neon' => (const Color(0xFFFF2BD6), const Color(0xFF00F0FF)),
      'winter' => (Colors.white.withValues(alpha: 0.55), const Color(0xFFA5F3FC)),
      'christmas' => (const Color(0xFFFDE68A), const Color(0xFFDC2626)),
      'newyear' => (const Color(0xFFFACC15), const Color(0xFFF472B6)),
      _ => (null, null),
    };
    if (border == null) return child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 2),
        boxShadow: [BoxShadow(color: glow!.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: -2)],
      ),
      child: child,
    );
  }

  /// Seasonal greeting banner, or null for themes without one.
  static Widget? greeting() {
    final now = DateTime.now();
    final (emoji, title, sub, colors) = switch (decor) {
      'christmas' => ('🎄', tr('home.season.christmas'), tr('home.season.christmas_sub'), const [Color(0xFFB91C1C), Color(0xFF14532D)]),
      'newyear' => (
          '🎆',
          tr('home.season.newyear', {'year': now.month == 12 ? now.year + 1 : now.year}),
          tr('home.season.newyear_sub'),
          const [Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
      'winter' => ('❄️', tr('home.season.winter'), tr('home.season.winter_sub'), const [Color(0xFF1E40AF), Color(0xFF0E7490)]),
      _ => (null, null, null, null),
    };
    if (emoji == null) return null;
    return Container(
      key: const ValueKey('theme_greeting'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: colors!),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.4), blurRadius: 16)],
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 34)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(sub!, style: const TextStyle(color: Pal.text, fontSize: 12.5, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}
