import 'package:flutter/material.dart';

import '../audio.dart';
import 'glass_card.dart';
import 'palette.dart';

/// Bottom sheet with Sound / Music / Vibration on-off switches. Opened from the
/// home screen and from the speaker button in every GameScaffold.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String sub, ValueNotifier<bool> n, Future<void> Function(bool) set) {
      return ValueListenableBuilder<bool>(
        valueListenable: n,
        builder: (_, on, _) => SwitchListTile(
          secondary: Icon(icon, color: on ? Pal.gold : Pal.textDim, size: 28),
          title: Text(title, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
          subtitle: Text(sub, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
          value: on,
          activeThumbColor: Pal.gold,
          onChanged: (v) {
            set(v);
            if (v) AppAudio.play(Sound.tap);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      child: GlassCard(
        radius: 28,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        gradient: LinearGradient(
          colors: [const Color(0xFF2A1F63).withValues(alpha: 0.97), const Color(0xFF140E38).withValues(alpha: 0.97)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Settings', style: TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
          row(Icons.volume_up_rounded, 'Sound effects', 'Tap, jeet, galti ki awaaz', AppAudio.soundOn, AppAudio.setSound),
          row(Icons.music_note_rounded, 'Music', 'Background music', AppAudio.musicOn, AppAudio.setMusicEnabled),
          row(Icons.vibration_rounded, 'Vibration', 'Halka haptic feedback', AppAudio.hapticsOn, AppAudio.setHaptics),
        ]),
      ),
    );
  }
}
