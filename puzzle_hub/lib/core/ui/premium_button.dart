import 'package:flutter/material.dart';

import 'glass_card.dart';
import 'palette.dart';

class PremiumButton extends StatelessWidget {
  const PremiumButton({super.key, required this.label, required this.onTap, this.icon, this.color, this.compact = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Pal.goldDeep;
    final enabled = onTap != null;
    final btn = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28, vertical: compact ? 10 : 15),
      decoration: BoxDecoration(
        gradient: enabled ? Pal.accent(c) : const LinearGradient(colors: [Color(0xFF55507A), Color(0xFF3C3860)]),
        borderRadius: BorderRadius.circular(40),
        boxShadow: enabled ? [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 6))] : null,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      // Scale the label down instead of overflowing on narrow screens / large font settings.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 8)],
          Text(label,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 14 : 17, letterSpacing: 0.3)),
        ]),
      ),
    );
    return enabled ? Pressable(onTap: onTap!, child: btn) : btn;
  }
}
