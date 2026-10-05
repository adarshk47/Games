import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/parking_jam/logic/parking_logic.dart';

ParkingState _board(List<Vehicle> vs, {int size = 6, Set<int>? obstacles}) =>
    ParkingState(size: size, vehicles: vs, obstacles: obstacles);

void main() {
  test('forward drive exits when the lane is clear', () {
    final s = _board([Vehicle(id: 0, row: 2, col: 1, length: 2, horizontal: true, facing: 1)]);
    final r = s.move(0);
    expect(r.exited, isTrue);
    expect(r.distance, 3);
    expect(s.isSolved, isTrue);
    expect(s.moves, 1);
  });

  test('drive stops next to a blocker and counts a move', () {
    final s = _board([
      Vehicle(id: 0, row: 2, col: 0, length: 2, horizontal: true, facing: 1),
      Vehicle(id: 1, row: 1, col: 4, length: 3, horizontal: false, facing: -1),
    ]);
    final r = s.move(0);
    expect(r.exited, isFalse);
    expect(r.distance, 2);
    expect(r.blocker, 1);
    expect(s.byId(0)!.col, 2);
    expect(s.moves, 1);
    // Bumping again without moving does not count.
    final r2 = s.move(0);
    expect(r2.moved, isFalse);
    expect(s.moves, 1);
    // Vertical truck faces up: exits upward... blocked? row 1..3, up is row 0 free.
    expect(s.move(1).exited, isTrue);
    expect(s.move(0).exited, isTrue);
    expect(s.isSolved, isTrue);
  });

  test('reverse drive moves tail first and can exit', () {
    final s = _board([
      Vehicle(id: 0, row: 0, col: 3, length: 2, horizontal: false, facing: -1),
      Vehicle(id: 1, row: 5, col: 3, length: 2, horizontal: true, facing: 1),
    ]);
    // Facing up, reverse goes down: stops at row 3-4 (blocked by vehicle 1 on row 5).
    final r = s.move(0, -1);
    expect(r.exited, isFalse);
    expect(r.blocker, 1);
    expect(s.byId(0)!.row, 3);
    expect(s.move(0, 1).exited, isTrue);
  });

  test('obstacles block like vehicles', () {
    final s = _board([Vehicle(id: 0, row: 1, col: 0, length: 2, horizontal: true, facing: 1)], obstacles: {1 * 6 + 4});
    final r = s.move(0);
    expect(r.blocker, MoveResult.kObstacle);
    expect(s.byId(0)!.col, 2);
    expect(s.exitHint(), (0, -1));
    expect(greedySolve(s), isNotNull);
    expect(greedySolve(s, forwardOnly: true), isNull);
  });

  test('stars by moves vs par', () {
    expect(pjStars(10, 10), 3);
    expect(pjStars(13, 10), 2);
    expect(pjStars(14, 10), 1);
    expect(pjStars(4, 2), 2);
    expect(pjStars(5, 2), 1);
  });

  test('generation is deterministic', () {
    final a = generateLevel(PjTier.hard, 7).state;
    final b = generateLevel(PjTier.hard, 7).state;
    expect(a.vehicles.map((v) => v.toString()).toList(), b.vehicles.map((v) => v.toString()).toList());
    expect(a.obstacles, b.obstacles);
    // The returned state is a copy: mutating it does not affect the next one.
    a.move(a.vehicles.first.id);
    expect(generateLevel(PjTier.hard, 7).state.moves, 0);
  });

  test('every level of every tier is valid and solvable', () {
    for (final t in PjTier.values) {
      var prevVehicles = 0;
      for (var l = 1; l <= kPjLevels; l++) {
        final lv = generateLevel(t, l);
        final s = lv.state;
        final cfg = PjConfig.of(t, l);
        expect(s.size, cfg.size);
        expect(s.size, inInclusiveRange(6, 10));
        expect(s.vehicles.length, greaterThanOrEqualTo((cfg.vehicles * 0.8).floor()), reason: '${t.id} L$l');
        // No overlaps, all inside, not on cones.
        final seen = <int>{...s.obstacles};
        for (final v in s.vehicles) {
          expect(v.length == 2 || v.length == 3, isTrue);
          for (final (r, c) in v.cells) {
            expect(r >= 0 && r < s.size && c >= 0 && c < s.size, isTrue);
            expect(seen.add(r * s.size + c), isTrue, reason: '${t.id} L$l overlap');
          }
        }
        // Stored tap-only solution clears the lot in exactly par moves.
        final play = s.clone();
        for (final id in lv.solution) {
          expect(play.move(id).exited, isTrue, reason: '${t.id} L$l v$id');
        }
        expect(play.isSolved, isTrue);
        expect(play.moves, lv.par);
        expect(greedySolve(s, forwardOnly: true), isNotNull, reason: '${t.id} L$l');
        if (lv.moveLimit != null) expect(lv.moveLimit, greaterThanOrEqualTo(lv.par));
        // Not trivially solved at the start: something is blocked.
        final g = s.grid();
        expect(s.vehicles.any((v) => !s.canExit(v.id, 1, g)), isTrue, reason: '${t.id} L$l trivial');
        prevVehicles = s.vehicles.length;
      }
      expect(prevVehicles, greaterThan(0));
    }
    expect(generateLevel(PjTier.easy, 1).moveLimit, isNull);
    expect(generateLevel(PjTier.hard, 1).moveLimit, isNotNull);
    expect(generateLevel(PjTier.extreme, 30).state.size, 10);
  });

  test('tier ids round-trip', () {
    for (final t in PjTier.values) {
      expect(PjTier.fromId(t.id), t);
    }
    expect(PjTier.fromId('nope'), PjTier.easy);
  });
}
