import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../rewards.dart';
import '../ui/palette.dart';

OverlayEntry? _entry;

/// Glassy toast near the bottom of the screen (quest done, badge unlocked).
/// Coexists with the coin toast that [Rewards.addCoins] shows at the top.
/// Silently does nothing when no navigator overlay is available (tests).
void showDailyToast({required String emoji, required String title, String? subtitle, Color color = Pal.gold}) {
  final overlay = Rewards.navKey.currentState?.overlay;
  if (overlay == null) return;
  _entry?.remove();
  final e = OverlayEntry(
    builder: (_) => Positioned(
      bottom: MediaQuery.of(overlay.context).padding.bottom + 96,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xF22A1F63), Color.lerp(const Color(0xF2140E38), color, 0.25)!]),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.8), width: 1.4),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 26)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: Pal.accent(color)),
                child: Text(emoji, style: const TextStyle(fontSize: 22, decoration: TextDecoration.none)),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Pal.text, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                  if (subtitle != null)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Pal.textDim, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                ]),
              ),
            ]),
          )
              .animate()
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.8, end: 0, curve: Curves.easeOutBack, duration: 450.ms)
              .then(delay: 2200.ms)
              .fadeOut(duration: 350.ms),
        ),
      ),
    ),
  );
  _entry = e;
  overlay.insert(e);
  Future.delayed(const Duration(milliseconds: 3300), () {
    if (_entry == e) {
      e.remove();
      _entry = null;
    }
  });
}
