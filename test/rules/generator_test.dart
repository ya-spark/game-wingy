import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/gap_generator.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/spire.dart';

import 'autopilot.dart';

List<SpirePair> gen(int seed, int n) {
  final g = GapGenerator(Random(seed));
  return [for (var i = 0; i < n; i++) g.next(i * 220.0)];
}

void main() {
  test('gap sizes and positions are valid for 20 seeds x 500 pairs', () {
    for (var seed = 0; seed < 20; seed++) {
      final pairs = gen(seed, 500);
      for (var i = 0; i < pairs.length; i++) {
        final p = pairs[i];
        expect(p.gapHeight, greaterThanOrEqualTo(150), reason: 'seed $seed');
        expect(p.baseCenterY - p.gapHeight / 2, greaterThanOrEqualTo(40));
        expect(p.baseCenterY + p.gapHeight / 2, lessThanOrEqualTo(584 - 40));
        if (i > 0) {
          expect(
            (p.baseCenterY - pairs[i - 1].baseCenterY).abs(),
            lessThanOrEqualTo(200 + 1e-9),
          );
        }
        if (p.number % 7 == 0) {
          expect(
            p.gapHeight,
            greaterThanOrEqualTo(GapGenerator.baseHeight(i) + 60),
          );
        }
        // Drifting gaps stay inside the margins over their whole motion.
        if (p.drifting) {
          expect(
            p.baseCenterY - 30 - p.gapHeight / 2,
            greaterThanOrEqualTo(40),
          );
          expect(p.baseCenterY + 30 + p.gapHeight / 2, lessThanOrEqualTo(544));
        }
      }
    }
  });

  test('base gap height shrinks 1.5 u per pair from 210 to the 150 floor', () {
    expect(GapGenerator.baseHeight(0), 210);
    expect(GapGenerator.baseHeight(2), 207);
    expect(GapGenerator.baseHeight(40), 150);
    expect(GapGenerator.baseHeight(300), 150);
  });

  test('drifting gaps only from pair 20, one in ten, +/-30 u, 2 s period', () {
    final pairs = gen(3, 200);
    final drifting = pairs.where((p) => p.drifting).toList();
    expect(
      drifting.map((p) => p.number).every((n) => n >= 20 && n % 10 == 0),
      isTrue,
    );
    expect(drifting.length, 19); // 20, 30, ..., 200
    final p = drifting.first;
    expect(p.centerYAt(0), p.baseCenterY);
    expect(p.centerYAt(0.5), closeTo(p.baseCenterY + 30, 1e-9));
    expect(p.centerYAt(1.5), closeTo(p.baseCenterY - 30, 1e-9));
    expect(p.centerYAt(2.0), closeTo(p.baseCenterY, 1e-9));
    expect(pairs.where((p) => p.number < 20).any((p) => p.drifting), isFalse);
  });

  test('orbs: pairs 3, 7, 11 always have one and never two in a row', () {
    for (var seed = 0; seed < 20; seed++) {
      final pairs = gen(seed, 300);
      for (final p in pairs) {
        if (p.number % 4 == 3) expect(p.hasOrb, isTrue);
      }
      for (var i = 1; i < pairs.length; i++) {
        expect(pairs[i].hasOrb && pairs[i - 1].hasOrb, isFalse);
      }
    }
  });

  test('same seed gives the same sequence, different seeds differ', () {
    List<double> centers(int s) =>
        gen(s, 50).map((p) => p.baseCenterY).toList();
    expect(centers(5), centers(5));
    expect(centers(5), isNot(centers(6)));
  });

  test('reference autopilot survives 500 pairs for 20 seeds', () {
    for (var seed = 0; seed < 20; seed++) {
      final run = playAutopilot(WingyRun(random: Random(seed)));
      expect(run.pairsPassed, greaterThanOrEqualTo(500), reason: 'seed $seed');
      expect(
        run.isPlaying,
        isTrue,
        reason: 'seed $seed died at ${run.pairsPassed}',
      );
    }
  });

  test('same seed and tap trace give identical score', () {
    int play(int seed) =>
        playAutopilot(WingyRun(random: Random(seed)), pairs: 60).score;
    expect(play(9), play(9));
  });
}
