import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/ads/ad_service.dart';
import 'package:wingy/game/rules/wingy_run.dart';
import 'package:wingy/game/rules/world.dart';
import 'package:wingy/ui/test_ids.dart';

import '../helpers/fake_services.dart';
import 'game_screen_test.dart' show frames, pumpGame, semValue, killHero;

/// Rewarded and interstitial ads always fail to load; there is no sign-in either
/// (the fake services use the local identity stub).
class _NoFillAds extends FakeAdService {
  _NoFillAds() : super(rewardResult: false);
  @override
  bool get isRewardedReady => false;
}

void main() {
  // Merge-gate bot: real taps on `game.field` through the widget tree, deciding from
  // the run state like a player watching the next gap.
  testWidgets('bot flies through spires with real taps and scores', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    var taps = 0;
    for (var i = 0; i < 1500 && !g.run.isDead && g.run.pairsPassed < 3; i++) {
      final next = g.run.pairs
          .where((p) => WingyWorld.heroX <= p.right + WingyWorld.heroRadius)
          .firstOrNull;
      final goal = next == null ? 300.0 : next.centerAt(next.age) + 25;
      if (g.run.y > goal && g.run.vy > -100) {
        await tester.tap(find.byKey(TestIds.gameField));
        taps++;
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(taps, greaterThan(3));
    expect(g.run.pairsPassed, greaterThanOrEqualTo(3));
    expect(
      int.parse(tester.widget<Text>(find.byKey(TestIds.gameScore)).data!),
      g.run.score,
    );
    expect(g.run.score, greaterThanOrEqualTo(3));
    expect(semValue(tester, TestIds.gameMeter), '${g.run.meter}');
  });

  testWidgets('ads failing to load and no sign-in: game over still works', (
    tester,
  ) async {
    final s = await buildFakeServices(ads: _NoFillAds());
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, g);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);

    // Revive ad fails: no revive, dialog stays.
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await frames(tester, 12);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(g.run.phase, RunPhase.dead);

    // Refill ad fails: no refill granted, no coins taken.
    final coins = s.profile.data.coins;
    await tester.tap(find.byKey(TestIds.gameOverRefill));
    await frames(tester, 8);
    await tester.tap(find.byKey(TestIds.gameRefillAd));
    await frames(tester, 8);
    expect(s.profile.dashRefills, 0);
    expect(s.profile.data.coins, coins);

    // The player can still dismiss the sheet and retry.
    if (find.byKey(TestIds.gameRefillSheet).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(200, 20));
      await frames(tester, 8);
    }
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await frames(tester, 12);
    expect(g.run.phase, RunPhase.ready);
    expect(g.run.meter, 0);
  });
}
