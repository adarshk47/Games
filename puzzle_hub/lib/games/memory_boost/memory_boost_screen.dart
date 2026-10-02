import 'package:flutter/material.dart';

import '../../core/storage.dart';
import 'card_match_game.dart';
import 'logic/card_deck.dart';
import 'number_memory_game.dart';
import 'simon_game.dart';

class MemoryBoostScreen extends StatefulWidget {
  const MemoryBoostScreen({super.key});
  @override
  State<MemoryBoostScreen> createState() => _MemoryBoostScreenState();
}

class _MemoryBoostScreenState extends State<MemoryBoostScreen> {
  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {}); // refresh best scores
  }

  @override
  Widget build(BuildContext context) {
    var cardStars = 0;
    for (var i = 0; i < cardLevels.length; i++) {
      cardStars += Storage.getInt(cardStarsKey(i));
    }
    final numBest = Storage.getInt(numberBestKey(3));
    final numBest1 = Storage.getInt(numberBestKey(1));
    return Scaffold(
      appBar: AppBar(title: const Text('Brain Gym')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(context, Icons.grid_view_rounded, Colors.purple, 'Card Match',
              'Flip pairs of cards. 2x2 up to 6x6.', 'Stars: $cardStars/${cardLevels.length * 3}',
              () => _open(const CardMatchScreen())),
          _tile(context, Icons.lightbulb_rounded, Colors.orange, 'Simon Sequence',
              'Repeat the growing light pattern.', 'Best streak: ${Storage.getInt(simonBestKey)}',
              () => _open(const SimonScreen())),
          _tile(context, Icons.pin_rounded, Colors.teal, 'Number Memory',
              'Remember the number, one more digit each round.', 'Best level: $numBest (sudden death: $numBest1)',
              () => _open(const NumberMemoryScreen())),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, Color color, String title, String sub, String best, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(sub, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(best, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}
