import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/ads/ad_service.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/game/flame/wingy_game.dart';
import 'package:wingy/game/rules/wingy_run.dart';
import 'package:wingy/game/rules/world.dart';
import 'package:wingy/ui/game_screen.dart';
import 'package:wingy/ui/test_ids.dart';

import '../helpers/fake_services.dart';

Future<void> frames(WidgetTester tester, [int n = 6, int ms = 50]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<WingyGame> pumpGame(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = WingyGame(run: WingyRun(random: Random(1)));
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  for (var i = 0; i < 40 && !game.isLoaded; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await frames(tester, 2);
  return game;
}

String? semValue(WidgetTester tester, Key key) =>
    tester.widget<Semantics>(find.byKey(key)).properties.value;

/// Keeps the hero alive and level while tests inspect the HUD.
void hover(WingyGame g) {
  g.run.y = 300;
  g.run.vy = 0;
}

Future<void> killHero(WidgetTester tester, WingyGame g) async {
  g.run.invulnTimer = 0;
  g.run.y = 600;
  await frames(tester, 3);
  // Death animation (0.6 s) then the dialog.
  await frames(tester, 20);
}

void main() {
  testWidgets('game screen has no banner; ready hint starts the run', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    expect(find.byKey(const Key('game.banner')), findsNothing);
    expect(find.byKey(TestIds.gameReady), findsOneWidget);
    expect(g.run.phase, RunPhase.ready);
    await tester.tap(find.byKey(TestIds.gameReady));
    await frames(tester, 2);
    expect(g.run.phase, RunPhase.playing);
    expect(find.byKey(TestIds.gameReady), findsNothing);
    expect(tester.widget<Text>(find.byKey(TestIds.gameScore)).data, '0');
  });

  testWidgets('tapping the field flaps', (tester) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await frames(tester, 1, 20);
    g.run.vy = 200;
    await tester.tap(find.byKey(TestIds.gameField));
    expect(g.run.phase, RunPhase.playing);
    expect(g.run.vy, -430);
  });

  testWidgets('dash button: off below 3 pips, ready at 3, active when used', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    hover(g);
    await frames(tester, 2);
    expect(semValue(tester, TestIds.gameMeter), '0');
    expect(semValue(tester, TestIds.gameDashState), 'off');
    g.run.meter = 2;
    hover(g);
    await frames(tester, 1);
    expect(semValue(tester, TestIds.gameMeter), '2');
    expect(semValue(tester, TestIds.gameDashState), 'off');
    g.run.meter = 3;
    hover(g);
    await frames(tester, 1);
    expect(semValue(tester, TestIds.gameDashState), 'ready');
    await tester.tap(find.byKey(TestIds.gameDash));
    await frames(tester, 2);
    expect(semValue(tester, TestIds.gameDashState), 'active');
    expect(semValue(tester, TestIds.gameMeter), '0');
    expect(g.run.isDashing, isTrue);
  });

  testWidgets('streak chip reads the Perfect streak', (tester) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    hover(g);
    g.run.perfectStreak = 4;
    await frames(tester, 2);
    expect(semValue(tester, TestIds.gameStreak), '4');
  });

  testWidgets('pause stops the run; resume counts down and swallows taps', (
    tester,
  ) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    hover(g);
    await tester.tap(find.byKey(TestIds.gamePause));
    await frames(tester, 2);
    expect(g.run.paused, isTrue);
    final t = g.run.time;
    await frames(tester, 5);
    expect(g.run.time, t);
    await tester.tap(find.byKey(TestIds.gamePauseResume));
    await frames(tester, 2);
    expect(find.byKey(TestIds.gameCountdown), findsOneWidget);
    final vy = g.run.vy;
    await tester.tap(find.byKey(TestIds.gameField), warnIfMissed: false);
    expect(g.run.vy, vy, reason: 'tap during countdown is ignored');
    await frames(tester, 30, 100);
    expect(find.byKey(TestIds.gameCountdown), findsNothing);
    expect(g.run.paused, isFalse);
    await tester.tap(find.byKey(TestIds.gameField));
    expect(g.run.vy, -430);
  });

  testWidgets('app going to the background pauses the run', (tester) async {
    final s = await buildFakeServices();
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    hover(g);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await frames(tester, 2);
    expect(g.run.paused, isTrue);
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
  });

  testWidgets('game over: score, best, medal; revive exactly once', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    g.run.score = 12;
    await killHero(tester, g);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(TestIds.gameOverScore)).data, '12');
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameOverMedal)).data,
      'Bronze',
    );
    expect(find.byKey(TestIds.gameOverBest), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);

    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await frames(tester, 12);
    expect(ads.rewardedShown, 1);
    expect(g.run.phase, RunPhase.playing);
    expect(g.run.score, 12);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);

    await killHero(tester, g);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRevive), findsNothing);
  });

  testWidgets('declined revive ad keeps the dialog; retry records the run', (
    tester,
  ) async {
    final ads = FakeAdService(rewardResult: false);
    final s = await buildFakeServices(ads: ads);
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, g);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await frames(tester, 12);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await frames(tester, 12);
    expect(g.run.phase, RunPhase.ready);
    expect(g.run.score, 0);
    expect(s.profile.data.stats.gamesPlayed, 1);
  });

  testWidgets(
    'Dash Refill with no stock: sheet, 40 coins, next run starts full',
    (tester) async {
      final s = await buildFakeServices();
      await s.profile.addCoins(100);
      final g = await pumpGame(tester, s);
      await tester.tap(find.byKey(TestIds.gameReady));
      await killHero(tester, g);
      await tester.tap(find.byKey(TestIds.gameOverRefill));
      await frames(tester, 8);
      expect(find.byKey(TestIds.gameRefillSheet), findsOneWidget);
      final before = s.profile.data.coins;
      await tester.tap(find.byKey(TestIds.gameRefillCoins));
      await frames(tester, 8);
      expect(s.profile.data.coins, before - 40);
      expect(s.profile.dashRefills, 1);
      await tester.tap(find.byKey(TestIds.gameOverRetry));
      await frames(tester, 4);
      expect(g.run.meter, 3);
      expect(s.profile.dashRefills, 0);
    },
  );

  testWidgets('Dash Refill via rewarded ad, capped at 3 per day', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    final g = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, g);
    await tester.tap(find.byKey(TestIds.gameOverRefill));
    await frames(tester, 8);
    await tester.tap(find.byKey(TestIds.gameRefillAd));
    await frames(tester, 8);
    expect(ads.rewardedShown, 1);
    expect(s.profile.dashRefills, 1);
    expect(s.profile.adRefillsLeft, 2);
    expect(AdPlacement.values, contains(AdPlacement.dashRefill));
  });

  test('world constants are unchanged by the UI layer', () {
    expect(WingyWorld.groundY, 584);
  });
}
