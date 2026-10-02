import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';

const Color mbTint = Color(0xFFB794FF);

enum DialogChoice { menu, extra, retry }

/// Shows a premium result dialog and returns the user's choice.
Future<DialogChoice> showResultDialog(
  BuildContext context, {
  required String title,
  String? message,
  String emoji = '🧠',
  int? stars,
  Color color = Pal.gold,
  String retryLabel = 'Try again',
  String? extraLabel,
}) async {
  final done = Completer<DialogChoice>();
  void finish(DialogChoice c) {
    if (!done.isCompleted) done.complete(c);
  }

  await showPremiumDialog(
    context,
    title: title,
    message: message,
    emoji: emoji,
    stars: stars,
    color: color,
    actions: [
      DialogAction('Back', () => finish(DialogChoice.menu)),
      if (extraLabel != null) DialogAction(extraLabel, () => finish(DialogChoice.extra)),
      DialogAction(retryLabel, () => finish(DialogChoice.retry), primary: true),
    ],
  );
  finish(DialogChoice.menu);
  return done.future;
}

/// Glass HUD pill (icon + text).
class StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const StatChip(this.icon, this.text, {super.key, this.color = mbTint});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 0,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
          child: Text(text,
              key: ValueKey(text),
              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
      ]),
    );
  }
}

String fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
