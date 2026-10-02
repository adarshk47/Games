import 'package:flutter/material.dart';

enum DialogChoice { menu, extra, retry }

/// Shows a game-over dialog and returns the user's choice.
Future<DialogChoice> showResultDialog(
  BuildContext context, {
  required String title,
  required List<Widget> body,
  String retryLabel = 'Try again',
  String? extraLabel,
}) async {
  final r = await showGeneralDialog<DialogChoice>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'result',
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (c, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (c, _, _) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: body),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, DialogChoice.menu), child: const Text('Back')),
        if (extraLabel != null)
          TextButton(onPressed: () => Navigator.pop(c, DialogChoice.extra), child: Text(extraLabel)),
        FilledButton(onPressed: () => Navigator.pop(c, DialogChoice.retry), child: Text(retryLabel)),
      ],
    ),
  );
  return r ?? DialogChoice.menu;
}

class StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const StatChip(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

String fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
