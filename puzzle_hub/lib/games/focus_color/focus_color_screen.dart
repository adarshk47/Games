import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/ui/ui.dart';
import 'focus_play.dart';
import 'logic/focus_common.dart';

class FocusColorScreen extends StatefulWidget {
  const FocusColorScreen({super.key});

  @override
  State<FocusColorScreen> createState() => _FocusColorScreenState();
}

class _FocusColorScreenState extends State<FocusColorScreen> {
  Future<void> _open(FocusModeInfo m) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FocusPlayScreen(info: m)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Focus Colors',
      tint: focusTint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text('Train your attention. Pick a mode.', style: TextStyle(color: Pal.textDim, fontSize: 15)),
          ),
          for (var i = 0; i < focusModes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _hero(focusModes[i]).animate(delay: (80 * i).ms).fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
            ),
        ],
      ),
    );
  }

  Widget _hero(FocusModeInfo m) {
    final best = m.best;
    return Pressable(
      onTap: () => _open(m),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: Pal.accent(m.color),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: m.color.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
            child: Icon(m.icon, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(m.blurb, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.3)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(best > 0 ? 'Best $best' : 'No score yet',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                StarRow(stars: starsFor(m.mode, best)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
