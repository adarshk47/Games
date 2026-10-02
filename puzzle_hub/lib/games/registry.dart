import 'package:flutter/material.dart';

import '../core/game_info.dart';
import 'arrows/arrows_screen.dart';
import 'ball_sort/ball_sort_screen.dart';
import 'cat_game/cat_game_screen.dart';
import 'memory_boost/memory_boost_screen.dart';
import 'sudoku/sudoku_screen.dart';

/// Each game exposes one root screen widget; the hub only knows about this list.
final List<GameInfo> games = [
  GameInfo(
    id: 'arrows',
    title: 'Arrows',
    subtitle: 'Saare arrows bahar nikalo',
    icon: Icons.arrow_upward_rounded,
    color: const Color(0xFFE17055),
    builder: (_) => const ArrowsScreen(),
  ),
  GameInfo(
    id: 'cat_game',
    title: 'Cat & Fish',
    subtitle: 'Billi ko machhli tak pahunchao',
    icon: Icons.pets,
    color: const Color(0xFFFDCB6E),
    builder: (_) => const CatGameScreen(),
  ),
  GameInfo(
    id: 'sudoku',
    title: 'Sudoku',
    subtitle: 'Classic number puzzle',
    icon: Icons.grid_on_rounded,
    color: const Color(0xFF0984E3),
    builder: (_) => const SudokuScreen(),
  ),
  GameInfo(
    id: 'ball_sort',
    title: 'Ball Sort',
    subtitle: 'Rang ke hisaab se sort karo',
    icon: Icons.science_rounded,
    color: const Color(0xFF00B894),
    builder: (_) => const BallSortScreen(),
  ),
  GameInfo(
    id: 'memory_boost',
    title: 'Memory Boost',
    subtitle: 'Yaaddasht tez karo',
    icon: Icons.psychology_rounded,
    color: const Color(0xFFA29BFE),
    builder: (_) => const MemoryBoostScreen(),
  ),
];
