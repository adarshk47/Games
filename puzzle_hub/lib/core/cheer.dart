import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'i18n/i18n.dart';
import 'rewards.dart';
import 'storage.dart';
import 'ui/palette.dart';

/// GenZ-style "wah kya khela" / "agli baar pakka" lines shown (and optionally
/// spoken) when a game ends. Two global settings: cheers on/off, voice on/off.
class Cheer {
  Cheer._();

  static const _kOn = 'set.cheer';
  static const _kVoice = 'set.cheer_voice';
  static const winCount = 3;
  static const loseCount = 3;

  static final ValueNotifier<bool> enabled = ValueNotifier(true);
  static final ValueNotifier<bool> voice = ValueNotifier(false);
  static final _rng = Random();
  static FlutterTts? _tts;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static void init() {
    enabled.value = Storage.globalBool(_kOn, true);
    voice.value = Storage.globalBool(_kVoice, false);
  }

  static Future<void> setEnabled(bool v) async {
    enabled.value = v;
    await Storage.setGlobalBool(_kOn, v);
  }

  static Future<void> setVoice(bool v) async {
    voice.value = v;
    await Storage.setGlobalBool(_kVoice, v);
  }

  /// A random line for a win or a loss in the current language.
  static String line({required bool won}) => tr(
    won
        ? 'cheer.win.${_rng.nextInt(winCount)}'
        : 'cheer.lose.${_rng.nextInt(loseCount)}',
  );

  static void win() => _show(true);
  static void lose() => _show(false);

  static void _show(bool won) {
    if (!enabled.value) return;
    // One cheer per result even if several hooks fire together.
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(seconds: 2)) return;
    _last = now;
    final text = line(won: won);
    _bubble(text, won);
    if (voice.value) _speak(text);
  }

  static Future<void> _speak(String text) async {
    try {
      _tts ??= FlutterTts();
      final lang = switch (I18n.lang.value) {
        AppLang.en => 'en-IN',
        AppLang.mr => 'mr-IN',
        AppLang.te => 'te-IN',
        AppLang.ta => 'ta-IN',
        AppLang.pa => 'pa-IN',
        _ => 'hi-IN', // hi, hinglish, bho, sa
      };
      await _tts!.setLanguage(lang);
      await _tts!.setSpeechRate(0.5);
      // Strip emoji so the voice doesn't read their names.
      await _tts!.speak(
        text.replaceAll(
          RegExp(r'[^\p{L}\p{M}\p{N}\p{P}\s]', unicode: true),
          '',
        ),
      );
    } catch (e) {
      debugPrint('cheer voice failed: $e');
    }
  }

  static void _bubble(String text, bool won) {
    final overlay = Rewards.navKey.currentState?.overlay;
    if (overlay == null) return;
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(ctx).padding.bottom + 110,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child:
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: Pal.accent(
                          won
                              ? const Color(0xFF7C5CFF)
                              : const Color(0xFFFF6FB5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 250.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      curve: Curves.elasticOut,
                      duration: 700.ms,
                    )
                    .then(delay: 2200.ms)
                    .fadeOut(duration: 400.ms),
          ),
        ),
      ),
    );
    overlay.insert(e);
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (e.mounted) e.remove();
    });
  }
}
