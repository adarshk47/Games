import 'package:flutter/material.dart';

import '../core/game_info.dart';
import 'arrows/arrows_screen.dart';
import 'ball_sort/ball_sort_screen.dart';
import 'cat_game/cat_game_screen.dart';
import 'focus_color/focus_color_screen.dart';
import 'game_2048/game_2048_screen.dart';
import 'memory_boost/memory_boost_screen.dart';
import 'mom_memory/mom_memory_screen.dart';
import 'sudoku/sudoku_screen.dart';

/// Each game exposes one root screen widget; the hub only knows about this list.
final List<GameInfo> games = [
  GameInfo(
    id: 'mom_memory',
    title: 'Mom Memory',
    subtitle: 'Garbhavastha ke liye shaant memory games',
    icon: Icons.favorite_rounded,
    emoji: '🤰',
    color: const Color(0xFFFF8FB8),
    featured: true,
    builder: (_) => const MomMemoryScreen(),
  ),
  GameInfo(
    id: 'arrows',
    title: 'Arrows',
    subtitle: 'Saare arrows bahar nikalo',
    icon: Icons.arrow_upward_rounded,
    emoji: '🏹',
    color: const Color(0xFFFF7A59),
    builder: (_) => const ArrowsScreen(),
  ),
  GameInfo(
    id: 'cat_game',
    title: 'Cat & Fish',
    subtitle: 'Billi ko machhli tak pahunchao',
    icon: Icons.pets,
    emoji: '🐱',
    color: const Color(0xFFFFC857),
    builder: (_) => const CatGameScreen(),
  ),
  GameInfo(
    id: 'sudoku',
    title: 'Sudoku',
    subtitle: 'Classic number puzzle',
    icon: Icons.grid_on_rounded,
    emoji: '🔢',
    color: const Color(0xFF4DA8FF),
    builder: (_) => const SudokuScreen(),
  ),
  GameInfo(
    id: 'ball_sort',
    title: 'Ball Sort',
    subtitle: 'Rang ke hisaab se sort karo',
    icon: Icons.science_rounded,
    emoji: '🧪',
    color: const Color(0xFF2EE6A8),
    builder: (_) => const BallSortScreen(),
  ),
  GameInfo(
    id: 'memory_boost',
    title: 'Memory Boost',
    subtitle: 'Yaaddasht tez karo',
    icon: Icons.psychology_rounded,
    emoji: '🧠',
    color: const Color(0xFFB794FF),
    builder: (_) => const MemoryBoostScreen(),
  ),
  GameInfo(
    id: 'game_2048',
    title: '2048',
    subtitle: 'Tiles merge karke 2048 banao',
    icon: Icons.apps_rounded,
    emoji: '🔶',
    color: const Color(0xFFFB923C),
    builder: (_) => const Game2048Screen(),
  ),
  GameInfo(
    id: 'focus_color',
    title: 'Focus Colors',
    subtitle: 'Dimag ko tez aur focused rakho',
    icon: Icons.palette_rounded,
    emoji: '🎨',
    color: const Color(0xFF5EEAD4),
    builder: (_) => const FocusColorScreen(),
  ),
];
