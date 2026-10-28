import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/world.dart';

WingyRun playing({int seed = 1, int meter = 0}) =>
    WingyRun(random: Random(seed), startPlaying: true, startMeter: meter);

void main() {
  group('Glow Dash', () {
    test('needs a full meter; starting resets it and lasts 1.2 s', () {
      final r = playing(meter: 2);
      expect(r.startDash(), isFalse);
      r.meter = 3;
      expect(r.canDash, isTrue);
      expect(r.startDash(), isTrue);
      expect(r.meter, 0);
      expect(r.isDashing, isTrue);
      // A second dash cannot start during the first.
      r.meter = 3;
      expect(r.startDash(), isFalse);
      var steps = 0;
      while (r.isDashing && steps < 1000) {
        r.y = 300;
        r.step();
        steps++;
      }
      expect(steps * WingyWorld.fixedDt, closeTo(1.2, 0.02));
      expect(r.graceRemaining, greaterThan(0));
    });

    test('ignores spires, holds altitude, scrolls 1.8x faster', () {
      final r = playing(meter: 3);
      r.y = 300;
      r.startDash();
      expect(r.effectiveSpeed, r.scrollSpeed * 1.8);
      final p = r.pairs.first;
      p.x = WingyWorld.mothX;
      // Put Wingy inside the top spire.
      r.y = (p.gapTopAt(0) - 5).clamp(WingyWorld.dashMinY, 600);
      final y0 = r.y;
      r.step();
      expect(r.isDead, isFalse);
      expect(r.vy, 0);
      expect(r.y, y0);
      expect(p.shattered, isTrue);
    });

    test('still dies on the ground and ceiling', () {
      final r = playing(meter: 3);
      r.startDash();
      // Dash clamps altitude into [40, 544] so it cannot reach the bounds by itself.
      r.y = 10;
      r.step();
      expect(r.y, WingyWorld.dashMinY);
      expect(r.isDead, isFalse);
    });

    test('each pair crossed adds exactly 3 and keeps the Perfect streak', () {
      final r = playing(meter: 3);
      r.perfectStreak = 2;
      r.y = 300;
      r.pairs.first.x = 160;
      r.startDash();
      final before = r.score;
      var crossed = 0;
      for (var i = 0; i < 100000 && r.isDashing; i++) {
        r.y = 300;
        r.step();
      }
      crossed = r.pairsPassed;
      expect(r.score - before, 3 * crossed);
      expect(crossed, greaterThanOrEqualTo(1));
      expect(r.dashShatters, crossed);
      expect(r.perfectStreak, 2);
    });

    test('0.4 s of grace after the dash keeps Wingy alive inside a spire', () {
      final r = playing(meter: 3);
      r.y = 300;
      r.startDash();
      for (var i = 0; i < 200 && r.isDashing; i++) {
        r.y = 300;
        r.step();
      }
      expect(r.isDashing, isFalse);
      expect(r.graceRemaining, closeTo(0.4, 1e-9));
      final p = r.pairs.firstWhere((p) => !p.shattered);
      p.x = WingyWorld.mothX;
      r.y = (p.gapTopAt(r.time) - 5).clamp(30, 600);
      r.vy = 0;
      r.step();
      expect(r.isDead, isFalse);
      // After grace, spires are deadly again.
      for (var i = 0; i < 60; i++) {
        r.y = 300;
        r.step();
      }
      expect(r.graceRemaining, 0);
    });

    test('pausing stops the dash timer', () {
      final r = playing(meter: 3);
      r.startDash();
      r.pause();
      final left = r.dashRemaining;
      for (var i = 0; i < 100; i++) {
        r.step();
      }
      expect(r.dashRemaining, left);
      r.resume();
      r.step();
      expect(r.dashRemaining, lessThan(left));
    });

    test('flaps are ignored while dashing', () {
      final r = playing(meter: 3);
      r.startDash();
      expect(r.flap(), isFalse);
    });

    test('a Dash Refill starts the run with a full meter', () {
      final r = WingyRun(random: Random(1), startMeter: 3);
      expect(r.meter, 3);
      r.flap();
      expect(r.canDash, isTrue);
    });
  });

  group('Revive', () {
    WingyRun died() {
      final r = playing(seed: 7);
      r.score = 12;
      r.perfectStreak = 3;
      r.meter = 2;
      r.y = WingyWorld.groundY - 12;
      r.vy = 100;
      r.step();
      expect(r.isDead, isTrue);
      return r;
    }

    test('available exactly once per run', () {
      final r = died();
      expect(r.canRevive, isTrue);
      expect(r.revive(), isTrue);
      expect(r.isPlaying, isTrue);
      r.y = WingyWorld.groundY - 12;
      r.invulnRemaining = 0;
      r.vy = 100;
      r.step();
      expect(r.isDead, isTrue);
      expect(r.canRevive, isFalse);
      expect(r.revive(), isFalse);
    });

    test('keeps score, streak and meter; clears spires within 300 u', () {
      final r = died();
      final nextCenter = r.pairs
          .where((p) => p.right > 86)
          .reduce((a, b) => a.x < b.x ? a : b)
          .centerYAt(r.time);
      r.revive();
      expect(r.score, 12);
      expect(r.perfectStreak, 3);
      expect(r.meter, 2);
      expect(r.y, closeTo(nextCenter, 1e-9));
      expect(r.vy, 0);
      expect(
        r.pairs.every((p) => p.x > WingyWorld.mothX + 300 || p.right <= 86),
        isTrue,
      );
      expect(r.invulnRemaining, 2.0);
    });

    test('is invulnerable for 2 s, then vulnerable again', () {
      final r = died();
      r.revive();
      var steps = 0;
      while (r.isInvulnerable && steps < 1000) {
        r.step();
        steps++;
        // Keep Wingy flying inside the world.
        r.y = 300;
        r.vy = 0;
        if (r.pairs.isNotEmpty && r.pairs.first.x < 150) {
          r.pairs.first.x = 400;
        }
      }
      expect(steps * WingyWorld.fixedDt, closeTo(2.0, 0.02));
    });

    test('cannot revive while alive', () {
      final r = playing();
      expect(r.revive(), isFalse);
    });
  });
}
