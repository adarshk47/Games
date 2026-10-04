import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/account/auth_screens.dart';
import 'core/ads/ads_service.dart';
import 'core/audio.dart';
import 'core/cloud/cloud_service.dart';
import 'core/daily/reminder_service.dart';
import 'core/rewards.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/ui/app_theme.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Storage.init();
  await AppThemeController.init();
  await AppAudio.init();
  // Optional services: a failure here must never block the app from starting.
  for (final init in [CloudService.init, AdsService.init, ReminderService.init]) {
    try {
      await init();
    } catch (e) {
      debugPrint('service init failed: $e');
    }
  }
  AppAudio.startMusic();
  runApp(const PuzzleHubApp());
}

class PuzzleHubApp extends StatelessWidget {
  const PuzzleHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeController.current,
      builder: (_, _, _) => MaterialApp(
        title: 'Master G',
        debugShowCheckedModeBanner: false,
        navigatorKey: Rewards.navKey,
        theme: buildTheme(Brightness.dark),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: const AuthGate(home: HomeScreen()),
      ),
    );
  }
}
