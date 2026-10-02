import 'package:flutter/material.dart';

import 'core/account/auth_screens.dart';
import 'core/audio.dart';
import 'core/rewards.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await AppAudio.init();
  AppAudio.startMusic();
  runApp(const PuzzleHubApp());
}

class PuzzleHubApp extends StatelessWidget {
  const PuzzleHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle Hub',
      debugShowCheckedModeBanner: false,
      navigatorKey: Rewards.navKey,
      theme: buildTheme(Brightness.dark),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const AuthGate(home: HomeScreen()),
    );
  }
}
