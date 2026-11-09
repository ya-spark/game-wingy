import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/wingy_run.dart';

void main() {
  test('a running run survives a JSON round trip, paused', () {
    final run = WingyRun(random: Random(5));
    run.flap();
    for (var i = 0; i < 600; i++) {
      run.advance(1 / 60);
      if (run.vy > 100) run.flap();
    }
    expect(run.isDead, isFalse);
    final json = jsonDecode(jsonEncode(run.toJson())) as Map<String, Object?>;
    final back = WingyRun.restore(json, bestScore: 0)!;
    expect(back.paused, isTrue);
    expect(back.phase, RunPhase.playing);
    expect(back.score, run.score);
    expect(back.y, run.y);
    expect(back.pairs.length, run.pairs.length);
    expect(back.pairs.first.x, run.pairs.first.x);
    expect(back.pairsPassed, run.pairsPassed);
  });

  test('a corrupt save gives null instead of throwing', () {
    expect(WingyRun.restore({'y': 'x'}, bestScore: 0), isNull);
  });
}
