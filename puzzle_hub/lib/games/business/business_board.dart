import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import 'logic/business_logic.dart';

/// Names on the two boards (cities stay in English, like on the real game).
class BizNames {
  static const _india = [
    'Start', 'Patna', '', 'Gaya', '', 'Railways', 'Ranchi', '', 'Varanasi', //
    '', 'Lucknow', 'Bijli Ghar', 'Kanpur', 'Jaipur', 'Airways', 'Indore', '', 'Bhopal', //
    '', 'Kolkata', '', 'Chennai', 'Hyderabad', 'Waterways', 'Bengaluru', 'Water Works', 'Pune', //
    '', 'Ahmedabad', 'Goa', '', 'Chandigarh', 'Roadways', '', 'Delhi', 'Mumbai',
  ];
  static const _world = [
    'Start', 'Cairo', '', 'Nairobi', '', 'Railways', 'Istanbul', '', 'Bangkok', //
    '', 'Rome', 'Power Co.', 'Madrid', 'Berlin', 'Airways', 'Sydney', '', 'Toronto', //
    '', 'Dubai', '', 'Singapore', 'Hong Kong', 'Shipping', 'Paris', 'Water Works', 'Tokyo', //
    '', 'London', 'Los Angeles', '', 'Zurich', 'Metro', '', 'New York', 'Mumbai',
  ];

  static String square(int s, {required bool world}) {
    final b = Biz.board[s];
    return switch (b.kind) {
      Sq.kismat => tr('biz.kismat'),
      Sq.khazana => tr('biz.khazana'),
      Sq.tax => tr(b.amount >= 1000 ? 'biz.income_tax' : 'biz.wealth_tax'),
      Sq.jail => tr('biz.jail'),
      Sq.club => tr('biz.club'),
      Sq.goJail => tr('biz.go_jail'),
      Sq.start => tr('biz.start'),
      _ => (world ? _world : _india)[s],
    };
  }

  static String money(int v, {required bool world}) => '${world ? '\$' : '₹'}$v';
}

const bizGroupColors = [
  Color(0xFF8D6E63), Color(0xFF4FC3F7), Color(0xFFEC407A), Color(0xFFFFA726), //
  Color(0xFFEF5350), Color(0xFFFFEE58), Color(0xFF66BB6A), Color(0xFF3F51B5),
];

const bizPlayerColors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFDD835)];

/// Grid cell (row, col) of each square on a 10×10 board, clockwise from
/// Start in the bottom-right corner.
(int, int) bizCell(int s) {
  if (s <= 9) return (9, 9 - s); // bottom row, right → left
  if (s <= 18) return (9 - (s - 9), 0); // left column, bottom → top
  if (s <= 27) return (0, s - 18); // top row, left → right
  return (s - 27, 9); // right column, top → bottom
}

class BusinessBoard extends StatelessWidget {
  const BusinessBoard({super.key, required this.game, required this.world, required this.center, this.onSquare});
  final BusinessGame game;
  final bool world;
  final Widget center;
  final ValueChanged<int>? onSquare;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, c) {
          final cell = c.maxWidth / 10;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1B5E20), width: 3),
            ),
            child: Stack(children: [
              for (var s = 0; s < Biz.size; s++)
                Positioned(
                  left: bizCell(s).$2 * cell,
                  top: bizCell(s).$1 * cell,
                  width: cell,
                  height: cell,
                  child: GestureDetector(
                    onTap: onSquare == null ? null : () => onSquare!(s),
                    child: _SquareTile(game: game, s: s, world: world, cell: cell),
                  ),
                ),
              Positioned(left: cell, top: cell, width: cell * 8, height: cell * 8, child: center),
              // Tokens.
              for (var p = 0; p < game.players; p++)
                if (!game.out[p])
                  AnimatedPositioned(
                    key: ValueKey('biz_token_$p'),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    left: bizCell(game.pos[p]).$2 * cell + cell * (0.12 + (p % 2) * 0.42),
                    top: bizCell(game.pos[p]).$1 * cell + cell * (0.38 + (p ~/ 2) * 0.3),
                    width: cell * 0.36,
                    height: cell * 0.36,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bizPlayerColors[p],
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
                      ),
                    ),
                  ),
            ]),
          );
        }),
      );
}

class _SquareTile extends StatelessWidget {
  const _SquareTile({required this.game, required this.s, required this.world, required this.cell});
  final BusinessGame game;
  final int s;
  final bool world;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final b = Biz.board[s];
    final o = game.owner[s];
    final corner = s % 9 == 0;
    final emoji = switch (b.kind) {
      Sq.start => '🏁',
      Sq.jail => '🚔',
      Sq.club => '🎉',
      Sq.goJail => '👮',
      Sq.kismat => '❓',
      Sq.khazana => '💰',
      Sq.tax => '🧾',
      Sq.transport => '🚆',
      Sq.utility => s == 11 ? '💡' : '🚰',
      Sq.city => '',
    };
    final name = BizNames.square(s, world: world);
    final fs = (cell * 0.17).clamp(5.0, 11.0);
    return Container(
      decoration: BoxDecoration(
        color: o >= 0 ? bizPlayerColors[o].withValues(alpha: 0.18) : Colors.white,
        border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.35), width: 0.6),
      ),
      child: Column(children: [
        if (b.kind == Sq.city)
          Container(
            height: cell * 0.2,
            color: bizGroupColors[b.group],
            alignment: Alignment.center,
            child: game.houses[s] == 0
                ? null
                : Text(game.houses[s] == 4 ? '🏨' : '🏠' * game.houses[s], style: TextStyle(fontSize: cell * 0.12, height: 1)),
          ),
        if (emoji.isNotEmpty) Text(emoji, style: TextStyle(fontSize: cell * (corner ? 0.34 : 0.26), height: 1.1)),
        Expanded(
          child: Center(
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: fs, height: 1.05, color: const Color(0xFF1B1B2F), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (o >= 0)
          Container(height: cell * 0.08, color: bizPlayerColors[o])
        else if (b.ownable)
          Text(BizNames.money(b.price, world: world), style: TextStyle(fontSize: fs * 0.85, color: Colors.black54, height: 1.1)),
      ]),
    );
  }
}
