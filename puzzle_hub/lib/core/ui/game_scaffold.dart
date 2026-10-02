import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'animated_background.dart';
import 'glass_card.dart';
import 'settings_sheet.dart';
import 'palette.dart';

/// Standard screen frame for every game: animated background, glass top bar
/// with back button, title and optional actions. Wrap the game body in this.
class GameScaffold extends StatelessWidget {
  const GameScaffold({super.key, required this.title, required this.body, this.tint, this.actions, this.onBack});
  final String title;
  final Widget body;
  final Color? tint;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg0,
      body: AnimatedBackground(
        tint: tint,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(children: [
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  radius: 16,
                  blur: 0,
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Pal.text),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ),
                ...?actions,
                BarAction(icon: Icons.tune_rounded, tooltip: 'Sound & settings', onTap: () => showSettingsSheet(context)),
              ]),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3, end: 0),
            Expanded(child: body),
          ]),
        ),
      ),
    );
  }
}

/// Small round glass icon button for app bar actions.
class BarAction extends StatelessWidget {
  const BarAction({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Tooltip(
          message: tooltip ?? '',
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              radius: 16,
              blur: 0,
              onTap: onTap ?? () {},
              child: Icon(icon, size: 20, color: Pal.text),
            ),
          ),
        ),
      );
}
