import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_logic.dart';

/// Soft pastel palette layered on top of the dark premium design system.
class Mm {
  Mm._();
  static const rose = Color(0xFFFF8FB8);
  static const lavender = Color(0xFFC9B6FF);
  static const peach = Color(0xFFFFC2A8);
  static const mint = Color(0xFF9DE6C8);
  static const sky = Color(0xFF9CD3FF);
  static const butter = Color(0xFFFFE3A3);
  static const pads = [rose, lavender, peach, mint, sky, butter];
  static const ink = Color(0xFF3B2A57); // dark text on pastel surfaces
}

final _rng = Random();
String pick(List<String> l) => l[_rng.nextInt(l.length)];

const praise = ['Bahut badhiya!', 'Wah, kamaal!', 'Shabaash!', 'Bilkul sahi!', 'Aap to expert ho!', 'Pyaara!'];
const gentle = ['Aaram se, koi jaldi nahi', 'Koi baat nahi, phir se dekhte hain', 'Dheere dheere, sab theek hai', 'Gehri saans lijiye'];

void softTap() => HapticFeedback.selectionClick();

/// Records a gentle daily visit; returns the current streak.
int recordPlay([DateTime? now]) {
  final t = now ?? DateTime.now();
  final s = nextStreak(Storage.getString('mom.lastDay'), Storage.getInt('mom.streak'), t);
  Storage.setInt('mom.streak', s);
  Storage.setString('mom.lastDay', dayKey(t));
  return s;
}

int currentStreak() {
  final last = Storage.getString('mom.lastDay');
  final s = Storage.getInt('mom.streak');
  if (last == null || s <= 0) return 0;
  final now = DateTime.now();
  final y = DateTime(now.year, now.month, now.day - 1);
  return (last == dayKey(now) || last == dayKey(y)) ? s : 0;
}

/// Frame used by all four mini games.
class MmPage extends StatelessWidget {
  const MmPage({super.key, required this.title, required this.body, this.actions});
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) =>
      GameScaffold(title: title, tint: const Color(0xFFFF8FB8), actions: actions, body: body);
}

class MmFootnote extends StatelessWidget {
  const MmFootnote({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
        child: Text(mmFootnote,
            textAlign: TextAlign.center,
            style: TextStyle(color: Pal.textDim.withValues(alpha: 0.7), fontSize: 11.5, height: 1.3)),
      );
}

Future<void> mmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String emoji = '🌸',
  int? stars,
  required List<DialogAction> actions,
}) =>
    showPremiumDialog(context, title: title, message: message, emoji: emoji, stars: stars, color: Mm.rose, actions: actions);

/// Soft pastel tile with an emoji or custom child.
class PastelTile extends StatelessWidget {
  const PastelTile({super.key, required this.color, required this.child, this.selected = false, this.radius = 20, this.dim = false});
  final Color color;
  final Widget child;
  final bool selected;
  final double radius;
  final bool dim;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: dim ? 0.35 : 0.9),
              color.withValues(alpha: dim ? 0.3 : 0.8),
            ],
          ),
          border: Border.all(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35), width: selected ? 2.5 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: -2)] : null,
        ),
        child: child,
      );
}
