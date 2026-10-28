import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/world.dart';
import 'package:wingy/ui/test_ids.dart';

import '../helpers/fake_services.dart';
import '../helpers/wingy_bot.dart';

void main() {
  testWidgets('game screen has the HUD and no banner', (tester) async {
    final s = await buildFakeServices();
    await pumpGame(tester, s);
    for (final k in [
      TestIds.gameWidget,
      TestIds.gameField,
      TestIds.gameScore,
      TestIds.gameBest,
      TestIds.gameMeter,
      TestIds.gameDash,
      TestIds.gameDashState,
      TestIds.gamePause,
      TestIds.gameBack,
      TestIds.gameReady,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    expect(find.byKey(TestIds.gameStreak), findsNothing);
  });

  testWidgets('tapping game.ready starts the run and flaps', (tester) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    expect(bot.run.phase, RunPhase.ready);
    await tester.tap(find.byKey(TestIds.gameReady));
    await tester.pump(const Duration(milliseconds: 20));
    expect(bot.run.phase, RunPhase.playing);
    expect(bot.run.vy, lessThan(0), reason: 'flapped upwards');
    expect(find.byKey(TestIds.gameReady), findsNothing);
  });

  testWidgets('tapping game.field flaps again', (tester) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    await bot.wait(400);
    expect(bot.run.vy, greaterThan(-300));
    await bot.tapField();
    expect(bot.run.vy, lessThan(-380));
  });

  testWidgets('score and meter are readable through the test IDs', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    expect(bot.scoreText(), '0');
    expect(bot.value(TestIds.gameMeter), '0');
    bot.run.begin();
    bot.run.score = 7;
    bot.run.meter = 2;
    bot.run.perfectStreak = 3;
    await bot.wait(100);
    expect(bot.scoreText(), '7');
    expect(bot.value(TestIds.gameMeter), '2');
    expect(find.byKey(TestIds.gameStreak), findsOneWidget);
  });

  testWidgets('Dash is off below 3 pips, ready at 3, active after a tap', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    // Keep Wingy flying while we look at the button.
    bot.run.y = 300;
    bot.run.meter = 2;
    await bot.wait(100);
    expect(bot.value(TestIds.gameDashState), 'off');
    expect(
      tester.widget<FilledButton>(find.byKey(TestIds.gameDash)).onPressed,
      isNull,
    );
    bot.run.meter = 3;
    await bot.wait(100);
    expect(bot.value(TestIds.gameDashState), 'ready');
    final y0 = bot.run.y;
    await tester.tap(find.byKey(TestIds.gameDash));
    await bot.wait(100);
    expect(bot.value(TestIds.gameDashState), 'active');
    expect(bot.value(TestIds.gameMeter), '0');
    expect(bot.run.isDashing, isTrue);
    // The Dash tap did not flap: altitude is held, not launched upwards.
    expect(bot.run.y, closeTo(y0, 20));
    await bot.wait(1400);
    expect(bot.value(TestIds.gameDashState), 'off');
  });

  testWidgets(
    'pause stops the run; resume counts down 3-2-1 and swallows taps',
    (tester) async {
      final s = await buildFakeServices();
      final bot = await pumpGame(tester, s);
      await bot.tapField();
      await tester.tap(find.byKey(TestIds.gamePause));
      await bot.wait(100);
      expect(bot.run.paused, isTrue);
      expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
      expect(find.byKey(TestIds.gamePauseQuit), findsOneWidget);
      final t = bot.run.time;
      await bot.wait(500);
      expect(bot.run.time, t);

      await tester.tap(find.byKey(TestIds.gamePauseResume));
      await bot.wait(100);
      expect(find.byKey(TestIds.gameCountdown), findsOneWidget);
      final vy = bot.run.vy;
      await bot.tapField(); // swallowed
      expect(bot.run.vy, vy);
      expect(bot.run.paused, isTrue);
      await bot.wait(3200);
      expect(bot.run.paused, isFalse);
      expect(find.byKey(TestIds.gameCountdown), findsNothing);
      await bot.tapField();
      expect(bot.run.vy, lessThan(-380));
    },
  );

  testWidgets('app going to the background pauses the run', (tester) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await bot.wait(100);
    expect(bot.run.paused, isTrue);
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
  });

  testWidgets('game over: dialog shows score, best and medal', (tester) async {
    final s = await buildFakeServices();
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    bot.run.score = 12;
    await bot.crash();
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(TestIds.gameOverScore)).data, '12');
    expect(find.byKey(TestIds.gameOverBest), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameOverMedal)).data,
      contains('Bronze'),
    );
  });

  testWidgets('revive is offered once; a second death has no revive', (
    tester,
  ) async {
    final ads = CountingAds();
    final s = await buildFakeServices(ads: ads);
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    bot.run.score = 5;
    await bot.crash();
    expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await bot.wait(300);
    expect(ads.rewardedShown, 1);
    expect(bot.run.isPlaying, isTrue);
    expect(bot.run.score, 5);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);

    // Invulnerable for 2 s, then die again.
    await bot.wait(2200);
    await bot.crash();
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRevive), findsNothing);
  });

  testWidgets('declined revive ad keeps the dialog', (tester) async {
    final ads = CountingAds(rewardResult: false);
    final s = await buildFakeServices(ads: ads);
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    await bot.crash();
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await bot.wait(300);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(bot.run.isDead, isTrue);
  });

  testWidgets('retry records the run, asks for an interstitial and restarts', (
    tester,
  ) async {
    final ads = CountingAds();
    final s = await buildFakeServices(ads: ads);
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    bot.run.score = 11;
    await bot.crash();
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await bot.wait(300);
    expect(ads.interstitialRequests, 1);
    expect(s.profile.data.stats.gamesPlayed, 1);
    expect(s.profile.data.bestScore, 11);
    expect(bot.run.phase, RunPhase.ready);
    expect(bot.run.score, 0);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);
  });

  testWidgets('home from game over records the run and leaves the game', (
    tester,
  ) async {
    final ads = CountingAds();
    final s = await buildFakeServices(ads: ads);
    final bot = await pumpGameFromHome(tester, s);
    await bot.tapField();
    await bot.crash();
    await tester.tap(find.byKey(TestIds.gameOverHome));
    await bot.wait(600);
    expect(ads.interstitialRequests, 1);
    expect(s.profile.data.stats.gamesPlayed, 1);
    expect(find.byKey(TestIds.gameWidget), findsNothing);
  });

  testWidgets('Dash Refill with no stock opens the sheet; coins pay 40', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.addCoins(100);
    final bot = await pumpGame(tester, s);
    await bot.tapField();
    await bot.crash();
    await tester.tap(find.byKey(TestIds.gameOverRefill));
    await bot.wait(300);
    expect(find.byKey(TestIds.gameRefillCoins), findsOneWidget);
    expect(find.byKey(TestIds.gameRefillAd), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameRefillCoins));
    await bot.wait(500);
    expect(s.profile.data.coins, 60);
    expect(s.profile.dashRefills, 1);
    // Back at the game over dialog with the refill armed.
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await bot.wait(400);
    expect(bot.run.meter, 3);
    expect(s.profile.dashRefills, 0, reason: 'spent on the new run');
    expect(bot.value(TestIds.gameMeter), '3');
  });

  testWidgets('Dash Refill via rewarded ad, at most 3 per day', (tester) async {
    final ads = CountingAds();
    final s = await buildFakeServices(ads: ads);
    final bot = await pumpGame(tester, s);
    for (var i = 0; i < 3; i++) {
      await bot.tapField();
      await bot.crash();
      await tester.tap(find.byKey(TestIds.gameOverRefill));
      await bot.wait(300);
      await tester.tap(find.byKey(TestIds.gameRefillAd));
      await bot.wait(500);
      expect(s.profile.dashRefills, 1, reason: 'round $i');
      await tester.tap(find.byKey(TestIds.gameOverRetry));
      await bot.wait(400);
      expect(bot.run.meter, 3);
    }
    expect(ads.rewardedShown, 3);
    expect(s.profile.adRefillsLeftToday, 0);
    // Fourth time: the ad button is disabled.
    await bot.tapField();
    await bot.crash();
    await tester.tap(find.byKey(TestIds.gameOverRefill));
    await bot.wait(300);
    expect(
      tester.widget<OutlinedButton>(find.byKey(TestIds.gameRefillAd)).onPressed,
      isNull,
    );
  });

  testWidgets('a stocked Dash Refill fills the meter before the run starts', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.addCoins(40);
    await s.profile.buyDashRefill();
    final bot = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReadyRefill));
    await bot.wait(300);
    expect(bot.run.meter, 3);
    expect(s.profile.dashRefills, 0);
    expect(bot.value(TestIds.gameMeter), '3');
  });

  testWidgets('same seed shows the same first gap', (tester) async {
    final s = await buildFakeServices();
    final a = seededGame(seed: 8);
    final b = seededGame(seed: 8);
    expect(a.run.pairs.first.baseCenterY, b.run.pairs.first.baseCenterY);
    await pumpGame(tester, s, game: a);
    expect(a.run.pairs.first.x, WingyWorld.mothX + 360);
  });
}
