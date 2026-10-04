import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'storage.dart';

/// Sound effects available to every game. Files live in assets/audio/NAME.wav.
enum Sound { tap, pop, flip, slide, success, win, fail, coin }

/// Background music tracks (looping).
enum MusicTrack { main, calm }

/// App-wide audio + haptics, with user settings (global, not per account so
/// they also apply on the lock screen). Safe to call from anywhere; it never
/// throws (audio failures are swallowed so a game can't crash on sound).
///
/// Games call:
///   AppAudio.play(Sound.pop);      // sfx
///   AppAudio.haptic();             // light vibration (respects setting)
///   AppAudio.setMusic(MusicTrack.calm) / AppAudio.setMusic(MusicTrack.main)
class AppAudio with WidgetsBindingObserver {
  AppAudio._();
  static final AppAudio I = AppAudio._();

  static final ValueNotifier<bool> soundOn = ValueNotifier(true);
  static final ValueNotifier<bool> musicOn = ValueNotifier(true);
  static final ValueNotifier<bool> hapticsOn = ValueNotifier(true);

  static const _kSound = 'set.sound';
  static const _kMusic = 'set.music';
  static const _kHaptics = 'set.haptics';

  final Map<Sound, List<AudioPlayer>> _pool = {};
  final Map<Sound, int> _next = {};
  AudioPlayer? _music;
  MusicTrack _track = MusicTrack.main;
  bool _musicStarted = false;
  bool _inForeground = true;
  bool _ready = false;

  /// Call once after [Storage.init].
  static Future<void> init() async {
    soundOn.value = Storage.globalBool(_kSound, true);
    musicOn.value = Storage.globalBool(_kMusic, true);
    hapticsOn.value = Storage.globalBool(_kHaptics, true);
    WidgetsBinding.instance.addObserver(I);
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
      I._ready = true;
    } catch (e) {
      debugPrint('audio init failed: $e');
    }
  }

  static Future<void> setSound(bool v) async {
    soundOn.value = v;
    await Storage.setGlobalBool(_kSound, v);
  }

  static Future<void> setMusicEnabled(bool v) async {
    musicOn.value = v;
    await Storage.setGlobalBool(_kMusic, v);
    if (v) {
      await I._startMusic();
    } else {
      await I._stopMusic();
    }
  }

  static Future<void> setHaptics(bool v) async {
    hapticsOn.value = v;
    await Storage.setGlobalBool(_kHaptics, v);
  }

  static void haptic([bool heavy = false]) {
    if (!hapticsOn.value) return;
    heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }

  /// Fire-and-forget sound effect.
  static void play(Sound s, {double volume = 0.8}) {
    if (!soundOn.value || !I._ready) return;
    I._play(s, volume);
  }

  Future<void> _play(Sound s, double volume) async {
    try {
      final list = _pool.putIfAbsent(s, () => List.generate(6, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop)));
      final i = (_next[s] ?? 0) % list.length;
      _next[s] = i + 1;
      var p = list[i];
      try {
        await p.stop();
      } catch (_) {}
      await p.play(AssetSource('audio/${s.name}.wav'), volume: volume);
    } catch (e) {
      debugPrint('sfx ${s.name} failed: $e');
      try {
        final list = _pool[s];
        if (list != null && list.isNotEmpty) {
          final idx = (_next[s]! - 1) % list.length;
          final newP = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
          list[idx] = newP;
          await newP.play(AssetSource('audio/${s.name}.wav'), volume: volume);
        }
      } catch (_) {}
    }
  }

  /// Switch (or start) background music. Does nothing if music is off, but
  /// remembers the track for when it is turned on.
  static Future<void> setMusic(MusicTrack t) async {
    if (I._track == t && I._musicStarted) return;
    I._track = t;
    if (!musicOn.value) return;
    await I._stopMusic();
    await I._startMusic();
  }

  /// Start music for the current track if enabled (call after login).
  static Future<void> startMusic() => I._startMusic();

  Future<void> _startMusic() async {
    if (!musicOn.value || !_ready || !_inForeground || _musicStarted) return;
    try {
      _music ??= AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.35);
      await _music!.play(AssetSource('audio/music_${_track.name}.wav'));
      _musicStarted = true;
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  Future<void> _stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
    _musicStarted = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      _startMusic();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _inForeground = false;
      _stopMusic();
    }
  }
}
