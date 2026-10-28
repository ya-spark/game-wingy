import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/world.dart';

WingyRun fresh() => WingyRun(random: Random(1), startPlaying: true);

void main() {
  test('gravity: vy is 150 u/s after 0.1 s with no taps', () {
    final r = fresh();
    for (var i = 0; i < 12; i++) {
      r.step();
    }
    expect(r.vy, closeTo(150, 1e-6));
  });

  test('falling speed never exceeds 700 u/s', () {
    final r = fresh();
    var maxVy = 0.0;
    for (var i = 0; i < 100 && r.isPlaying; i++) {
      r.y = 200; // keep it in the air
      r.step();
      maxVy = max(maxVy, r.vy);
    }
    expect(maxVy, 700);
  });

  test('a flap sets vy to exactly -430 regardless of prior vy', () {
    final r = fresh();
    r.vy = 600;
    expect(r.flap(), isTrue);
    expect(r.vy, -430);
    r.flap();
    expect(r.vy, -430, reason: 'flaps do not stack');
  });

  test('first flap starts the run', () {
    final r = WingyRun(random: Random(1));
    expect(r.phase, RunPhase.ready);
    r.step();
    expect(r.y, WingyWorld.startY, reason: 'hovers while waiting');
    r.flap();
    expect(r.phase, RunPhase.playing);
    expect(r.vy, -430);
  });

  test('ground ends the run', () {
    final r = fresh();
    r.y = WingyWorld.groundY - WingyWorld.mothRadius - 0.5;
    r.vy = 100;
    r.step();
    expect(r.isDead, isTrue);
    expect(r.drainEvents().map((e) => e.kind), contains(RunEventKind.hit));
  });

  test('ceiling ends the run', () {
    final r = fresh();
    r.y = WingyWorld.mothRadius + 0.5;
    r.vy = -430;
    r.step();
    expect(r.isDead, isTrue);
  });

  test('scroll speed: 140 at start, +2 per pass, 220 cap', () {
    final r = fresh();
    expect(r.scrollSpeed, 140);
    r.pairsPassed = 1;
    expect(r.scrollSpeed, 142);
    r.pairsPassed = 40;
    expect(r.scrollSpeed, 220);
    r.pairsPassed = 400;
    expect(r.scrollSpeed, 220);
  });

  test('first pair appears 360 u after the moth and pairs are 220 u apart', () {
    final r = fresh();
    expect(r.pairs.first.x, WingyWorld.mothX + 360);
    expect(r.pairs[1].x - r.pairs[0].x, 220);
  });

  test('pause stops the simulation', () {
    final r = fresh();
    r.pause();
    final y0 = r.y;
    for (var i = 0; i < 50; i++) {
      r.step();
    }
    expect(r.y, y0);
    expect(r.time, 0);
    expect(r.flap(), isFalse);
    r.resume();
    r.step();
    expect(r.y, isNot(y0));
  });

  test('palette and medals follow the score', () {
    expect(paletteForScore(0), WingyPalette.dusk);
    expect(paletteForScore(24), WingyPalette.dusk);
    expect(paletteForScore(25), WingyPalette.aurora);
    expect(paletteForScore(59), WingyPalette.aurora);
    expect(paletteForScore(60), WingyPalette.midnight);
    expect(medalForScore(9), Medal.none);
    expect(medalForScore(10), Medal.bronze);
    expect(medalForScore(25), Medal.silver);
    expect(medalForScore(50), Medal.gold);
    expect(medalForScore(100), Medal.prism);
    expect(scoreCoins(24), 4);
  });
}
