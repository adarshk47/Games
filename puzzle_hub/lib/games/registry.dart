import 'package:flutter/material.dart';

import '../core/game_info.dart';
import 'arrow_maze/arrow_maze_screen.dart';
import 'arrows/arrows_screen.dart';
import 'ball_sort/ball_sort_screen.dart';
import 'block_puzzle/block_puzzle_screen.dart';
import 'flow_pairs/flow_pairs_screen.dart';
import 'focus_color/focus_color_screen.dart';
import 'game_2048/game_2048_screen.dart';
import 'hexa_sort/hexa_sort_screen.dart';
import 'maze_escape/maze_escape_screen.dart';
import 'memory_boost/memory_boost_screen.dart';
import 'minesweeper/minesweeper_screen.dart';
import 'mom_memory/mom_memory_screen.dart';
import 'parking_jam/parking_jam_screen.dart';
import 'screw_jam/screw_jam_screen.dart';
import 'sliding_puzzle/sliding_puzzle_screen.dart';
import 'sudoku/sudoku_screen.dart';
import 'tile_match/tile_match_screen.dart';

/// Games shown in the hub (only those with `enabled: true`).
/// Test builds can show hidden games too:
///   flutter build apk --debug --dart-define=SHOW_ALL_GAMES=true
/// Release builds never set it, so hidden games stay hidden there.
const bool kShowAllGames = bool.fromEnvironment('SHOW_ALL_GAMES');

final List<GameInfo> games = [for (final g in allGames) if (g.enabled || kShowAllGames) g];

/// Every game that exists in the codebase. To release a hidden game, flip its
/// `enabled` flag to true (and bump the version).
final List<GameInfo> allGames = [
  // Hidden for now (preserved for a future release).
  GameInfo(
    id: 'mom_memory',
    title: 'Mom Memory',
    subtitle: 'Garbhavastha ke liye shaant memory games',
    icon: Icons.favorite_rounded,
    emoji: '🤰',
    color: const Color(0xFFFF8FB8),
    featured: true,
    enabled: false,
    builder: (_) => const MomMemoryScreen(),
  ),
  GameInfo(
    id: 'block_puzzle',
    title: 'Block Puzzle',
    subtitle: 'Blocks girao, lines saaf karo',
    icon: Icons.view_module_rounded,
    emoji: '🧱',
    color: const Color(0xFFFF6FB5),
    builder: (_) => const BlockPuzzleScreen(),
  ),
  GameInfo(
    id: 'flow_pairs',
    title: 'Flow',
    subtitle: 'Same rang ke dots jodo',
    icon: Icons.timeline_rounded,
    emoji: '🔗',
    color: const Color(0xFF5EEAD4),
    builder: (_) => const FlowPairsScreen(),
  ),
  GameInfo(
    id: 'sliding_puzzle',
    title: 'Sliding Puzzle',
    subtitle: 'Tiles ko sahi order mein lagao',
    icon: Icons.grid_view_rounded,
    emoji: '🧩',
    color: const Color(0xFFB794FF),
    builder: (_) => const SlidingPuzzleScreen(),
  ),
  GameInfo(
    id: 'minesweeper',
    title: 'Minesweeper',
    subtitle: 'Mines bachakar board saaf karo',
    icon: Icons.flag_rounded,
    emoji: '💣',
    color: const Color(0xFFFB923C),
    builder: (_) => const MinesweeperScreen(),
  ),
  GameInfo(
    id: 'arrow_maze',
    title: 'Arrow Maze',
    subtitle: 'Lambe arrows ko bahar nikalo',
    icon: Icons.alt_route_rounded,
    emoji: '➰',
    color: const Color(0xFF7C9CFF),
    builder: (_) => const ArrowMazeScreen(),
  ),
  GameInfo(
    id: 'screw_jam',
    title: 'Screw Jam',
    subtitle: 'Screws nikalo, plates girao',
    icon: Icons.hardware_rounded,
    emoji: '🔩',
    color: const Color(0xFF94A3B8),
    builder: (_) => const ScrewJamScreen(),
  ),
  GameInfo(
    id: 'parking_jam',
    title: 'Parking Jam',
    subtitle: 'Gaadiyan nikalo, parking khali karo',
    icon: Icons.directions_car_rounded,
    emoji: '🚗',
    color: const Color(0xFFEF4444),
    builder: (_) => const ParkingJamScreen(),
  ),
  GameInfo(
    id: 'tile_match',
    title: 'Tile Match',
    subtitle: 'Teen jaise tiles jodo',
    icon: Icons.style_rounded,
    emoji: '🀄',
    color: const Color(0xFF34D399),
    builder: (_) => const TileMatchScreen(),
  ),
  GameInfo(
    id: 'hexa_sort',
    title: 'Hexa Sort',
    subtitle: 'Hexagon stacks rang se jodo',
    icon: Icons.hexagon_rounded,
    emoji: '⬢',
    color: const Color(0xFFF472B6),
    builder: (_) => const HexaSortScreen(),
  ),
  GameInfo(
    id: 'maze_escape',
    title: 'Maze Escape',
    subtitle: 'Bhool-bhulaiya se sahi raasta dhoondo',
    icon: Icons.route_rounded,
    emoji: '🧭',
    color: const Color(0xFFFFC857),
    builder: (_) => const MazeEscapeScreen(),
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
  GameInfo(
    id: 'arrows',
    title: 'Arrows',
    subtitle: 'Saare arrows bahar nikalo',
    icon: Icons.arrow_upward_rounded,
    emoji: '🏹',
    color: const Color(0xFFFF7A59),
    builder: (_) => const ArrowsScreen(),
  ),
];
