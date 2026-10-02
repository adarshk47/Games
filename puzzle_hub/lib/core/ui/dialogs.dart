import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'glass_card.dart';
import 'palette.dart';
import 'premium_button.dart';

class DialogAction {
  const DialogAction(this.label, this.onTap, {this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// Premium result dialog (win / game over / info). Pass 0-3 [stars] to show a
/// star row. Each action closes the dialog and then runs its callback.
Future<void> showPremiumDialog(
  BuildContext context, {
  required String title,
  String? message,
  String emoji = '🎉',
  int? stars,
  Color color = Pal.gold,
  required List<DialogAction> actions,
  bool dismissible = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
    ),
    pageBuilder: (ctx, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            radius: 32,
            glow: color,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF2A1F63).withValues(alpha: 0.96), const Color(0xFF140E38).withValues(alpha: 0.96)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 54))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.1, 1.1), duration: 900.ms),
              const SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w900)),
              if (stars != null) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 3; i++)
                    Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 42, color: i < stars ? Pal.gold : Pal.textDim)
                        .animate(delay: (350 + i * 220).ms)
                        .scale(begin: const Offset(0, 0), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 600.ms),
                ]),
              ],
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 15, height: 1.4)),
              ],
              const SizedBox(height: 22),
              Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                for (final a in actions)
                  PremiumButton(
                    label: a.label,
                    compact: true,
                    color: a.primary ? null : const Color(0xFF6F63B8),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      a.onTap();
                    },
                  ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Read-only star display for level tiles.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 14});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < stars ? Pal.gold : Pal.textDim),
      ]);
}
