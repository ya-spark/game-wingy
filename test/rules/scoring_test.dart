import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/spire.dart';
import 'package:wingy/game/rules/world.dart';

import 'autopilot.dart';

/// Run that holds Wingy at [offset] from the center of each next gap until [passes] pairs
/// are passed. Returns the points gained per pass.
List<int> passWith(WingyRun run, List<double> offsets) {
  final gains = <int>[];
  var last = run.score;
  run.begin();
  for (var n = 0; n < offsets.length; n++) {
    final target = run.pairsPassed + 1;
    for (
      var i = 0;
      i < 100000 && run.pairsPassed < target && run.isPlaying;
      i++
    ) {
      // Aim at a gap until Wingy's body has cleared its spires.
      final p = run.pairs.firstWhere(
        (p) => p.right + WingyWorld.mothRadius + 2 > WingyWorld.mothX,
      );
      // Stay safe inside the gap, but sit at the requested offset when passing.
      run.y = p.centerYAt(run.time) + offsets[n];
      run.vy = 0;
      // Orbs would add points; keep them out of the way for a clean score test.
      for (final q in run.pairs) {
        q.orbTaken = true;
      }
      run.step();
    }
    gains.add(run.score - last);
    last = run.score;
  }
  return gains;
}

void main() {
  test('first pass scores 1 off-center and 2 when centered', () {
    final off = WingyRun(random: Random(2));
    final h = off.pairs.first.gapHeight;
    expect(passWith(off, [h * 0.4]), [1]);
    final centered = WingyRun(random: Random(2));
    expect(passWith(centered, [0]), [2]);
  });

  test('middle 30% boundary: 15% of the gap height is still perfect', () {
    final r = WingyRun(random: Random(3));
    final h = r.pairs.first.gapHeight;
    expect(passWith(r, [h * 0.149]), [2]);
    final r2 = WingyRun(random: Random(3));
    expect(passWith(r2, [h * 0.16]), [1]);
  });

  test(
    'Perfect streak and Bloom: 2, 2, 3, 4, 5, 6, 7, 7 and reset on a miss',
    () {
      final r = WingyRun(random: Random(4));
      final gains = passWith(r, List.filled(8, 0.0));
      expect(gains, [2, 2, 3, 4, 5, 6, 7, 7]);
      expect(r.perfectStreak, 8);
      expect(r.maxPerfectStreak, 8);
      expect(r.bloomHits, greaterThan(0));
      final h = r.nextPair!.gapHeight;
      expect(passWith(r, [h * 0.4]), [1]);
      expect(r.perfectStreak, 0);
      expect(r.maxPerfectStreak, 8);
    },
  );

  test('best score follows the score', () {
    final r = WingyRun(random: Random(4), bestScore: 1);
    passWith(r, [0, 0]);
    expect(r.bestScore, r.score);
  });

  test('orb: +1 score, +1 meter pip (max 3), +1 coin, coin cap 40', () {
    final r = WingyRun(random: Random(5), startPlaying: true);
    final orb = r.pairs.firstWhere((p) => p.hasOrb);
    void take(SpirePair p) {
      p.x = WingyWorld.mothX;
      r.y = p.centerYAt(r.time);
      r.vy = 0;
      r.step();
    }

    take(orb);
    expect(r.score, 1);
    expect(r.meter, 1);
    expect(r.runCoins, 1);
    expect(r.orbsCollected, 1);
    expect(r.drainEvents().any((e) => e.kind == RunEventKind.orb), isTrue);
    // The same orb cannot be taken twice.
    r.step();
    expect(r.orbsCollected, 1);
    r.meter = 3;
    r.runCoins = 40;
    var other = r.generator.next(1000);
    while (!other.hasOrb) {
      other = r.generator.next(1000);
    }
    r.pairs.add(other);
    other.x = WingyWorld.mothX;
    r.y = other.centerYAt(r.time);
    r.vy = 0;
    r.step();
    expect(r.meter, 3);
    expect(r.runCoins, 40);
  });

  test('summary reports coins as orb coins plus 1 per 5 points', () {
    final r = WingyRun(random: Random(5), startPlaying: true);
    r.score = 23;
    r.runCoins = 3;
    expect(r.summary().coins, 3 + 4);
  });

  test('hitting a spire ends the run', () {
    final r = WingyRun(random: Random(6), startPlaying: true);
    final p = r.pairs.first;
    p.x = WingyWorld.mothX;
    r.y = p.centerYAt(0) - p.gapHeight / 2 - 5; // inside the top spire
    r.vy = 0;
    r.step();
    expect(r.isDead, isTrue);
  });

  test('death lasts 0.6 s before the game over dialog', () {
    final r = WingyRun(random: Random(6), startPlaying: true);
    r.y = 500;
    r.vy = 700;
    for (var i = 0; i < 20 && !r.isDead; i++) {
      r.step();
    }
    expect(r.isDead, isTrue);
    expect(r.gameOverReady, isFalse);
    for (var i = 0; i < 72; i++) {
      r.step();
    }
    expect(r.gameOverReady, isTrue);
  });

  test('same seed and tap trace replay identically', () {
    WingyRun play(int seed) {
      final run = WingyRun(random: Random(seed));
      run.begin();
      for (var i = 0; i < 30000 && run.isPlaying; i++) {
        if (autopilotWants(run)) run.flap();
        run.step();
      }
      return run;
    }

    final a = play(11);
    final b = play(11);
    expect(a.score, b.score);
    expect(a.time, b.time);
    expect(
      a.pairs.map((p) => p.baseCenterY),
      b.pairs.map((p) => p.baseCenterY),
    );
  });
}
