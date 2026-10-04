import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../storage.dart';
import 'daily_reward.dart';
import 'daily_service.dart';

/// Daily "come back and play" local notification. Every call is guarded: on
/// unsupported platforms, in tests, or when the plugin fails it is a no-op.
class ReminderService {
  ReminderService._();

  static const _kOn = 'reminder.on';
  static const _kHour = 'reminder.hour';
  static const _kMinute = 'reminder.minute';
  static const _kAsked = 'reminder.asked';
  static const _id = 7001;

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  static final ValueNotifier<TimeOfDay> time = ValueNotifier<TimeOfDay>(const TimeOfDay(hour: 19, minute: 0));

  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _ready = false;

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Called from main(). Also starts the daily quests / achievements listener.
  static Future<void> init() async {
    try {
      DailyService.init();
    } catch (e) {
      debugPrint('DailyService.init failed: $e');
    }
    _loadPrefs();
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        debugPrint('timezone lookup failed: $e');
      }
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
      );
      _plugin = plugin;
      _ready = true;
      // Refresh the scheduled message (streak day etc.) on every launch.
      if (enabled.value && _getGlobalBool(_kAsked)) await reschedule();
    } catch (e) {
      debugPrint('reminder init failed: $e');
    }
  }

  static bool _getGlobalBool(String k, [bool def = false]) {
    try {
      return Storage.globalBool(k, def);
    } catch (_) {
      return def;
    }
  }

  static int _getGlobalInt(String k, int def) {
    try {
      return int.tryParse(Storage.globalString(k) ?? '') ?? def;
    } catch (_) {
      return def;
    }
  }

  static void _loadPrefs() {
    enabled.value = _getGlobalBool(_kOn, true);
    time.value = TimeOfDay(hour: _getGlobalInt(_kHour, 19), minute: _getGlobalInt(_kMinute, 0));
  }

  /// Ask for notification permission once (first time home is reached).
  static Future<void> ensurePermissionPrompt() async {
    // Plugin unavailable (tests, desktop, init failure): leave settings untouched.
    if (!_ready) return;
    try {
      if (_getGlobalBool(_kAsked)) return;
      await Storage.setGlobalBool(_kAsked, true);
      if (!enabled.value) return;
      final ok = await _requestPermission();
      if (!ok) {
        enabled.value = false;
        await Storage.setGlobalBool(_kOn, false);
        return;
      }
      await reschedule();
    } catch (e) {
      debugPrint('reminder permission prompt failed: $e');
    }
  }

  static Future<bool> _requestPermission() async {
    final p = _plugin;
    if (!_ready || p == null) return false;
    try {
      if (Platform.isAndroid) {
        final a = p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await a?.requestNotificationsPermission() ?? true;
      }
      if (Platform.isIOS) {
        final i = p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('notification permission failed: $e');
    }
    return false;
  }

  /// Turns the reminder on/off. Returns the resulting state (false if the
  /// user denied permission).
  static Future<bool> setEnabled(bool on) async {
    try {
      if (on) {
        await Storage.setGlobalBool(_kAsked, true);
        if (_ready && !await _requestPermission()) on = false;
      }
      enabled.value = on;
      await Storage.setGlobalBool(_kOn, on);
      on ? await reschedule() : await _cancel();
    } catch (e) {
      debugPrint('reminder toggle failed: $e');
    }
    return enabled.value;
  }

  static Future<void> setTime(TimeOfDay t) async {
    time.value = t;
    try {
      await Storage.setGlobalString(_kHour, '${t.hour}');
      await Storage.setGlobalString(_kMinute, '${t.minute}');
      if (enabled.value) await reschedule();
    } catch (e) {
      debugPrint('reminder time failed: $e');
    }
  }

  /// Friendly rotating Hinglish message for [now].
  static String messageFor(DateTime now, {required int streak, required bool rewardReady}) {
    final msgs = <String>[
      'Aaj ka puzzle aapka intezaar kar raha hai 🧩',
      if (streak > 0) 'Streak mat todiye! 🔥 Day ${streak + 1}',
      if (rewardReady || streak > 0) 'Daily reward ready hai 🎁',
      'Aaj ke 3 quests ready hain, coins jeetiye 🪙',
      'Bas 5 minute, dimaag ki thodi kasrat 🧠',
    ];
    final dayOfYear = daysBetween(DateTime(now.year), now);
    return msgs[dayOfYear % msgs.length];
  }

  static Future<void> reschedule() async {
    final p = _plugin;
    if (!_ready || p == null || !enabled.value) return;
    try {
      await p.cancel(id: _id);
      final now = tz.TZDateTime.now(tz.local);
      final t = time.value;
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      int streak = 0;
      try {
        streak = DailyReward.streak;
      } catch (_) {}
      await p.zonedSchedule(
        id: _id,
        title: 'Master G',
        body: messageFor(at, streak: streak, rewardReady: true),
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('daily_reminder', 'Daily reminder',
              channelDescription: 'Daily puzzle reminder', importance: Importance.defaultImportance),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('reminder schedule failed: $e');
    }
  }

  static Future<void> _cancel() async {
    try {
      await _plugin?.cancel(id: _id);
    } catch (e) {
      debugPrint('reminder cancel failed: $e');
    }
  }
}
