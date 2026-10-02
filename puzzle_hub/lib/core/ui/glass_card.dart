import 'dart:ui';

import 'package:flutter/material.dart';

import 'palette.dart';

/// Frosted-glass surface. Set [blur] to 0 inside long scrolling lists / grids
/// for performance.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 14,
    this.gradient,
    this.onTap,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: gradient ??
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
            ),
        border: Border.all(color: Pal.glassBorder, width: 1),
      ),
      child: child,
    );
    if (blur > 0) {
      body = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: body),
      );
    }
    if (glow != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          boxShadow: [BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: -4)],
        ),
        child: body,
      );
    }
    if (onTap == null) return body;
    return Pressable(onTap: onTap!, child: body);
  }
}

/// Scale-on-press wrapper used by cards, buttons and custom tappable pieces.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
