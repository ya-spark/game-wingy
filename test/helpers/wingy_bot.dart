import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/ads/ad_service.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/game/flame/wingy_game.dart';
import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/ui/game_screen.dart';
import 'package:wingy/ui/test_ids.dart';

/// Rewarded ads succeed; counts interstitial requests.
class CountingAds extends FakeAdService {
  CountingAds({super.rewardResult});
  int interstitialRequests = 0;

  @override
  Future<bool> maybeShowInterstitialAfterGameOver() async {
    interstitialRequests++;
    return false;
  }
}

/// A game with a seeded generator, so runs repeat exactly.
WingyGame seededGame({int seed = 3, int best = 0}) => WingyGame(
  bestScore: best,
  runFactory: (best, meter) =>
      WingyRun(random: Random(seed), bestScore: best, startMeter: meter),
);

/// Mounts the game screen directly (without the home screen).
Future<WingyBot> pumpGame(
  WidgetTester tester,
  Services s, {
  WingyGame? game,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final g = game ?? seededGame();
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: g)),
    ),
  );
  final bot = WingyBot(tester);
  await bot.waitForGame();
  return bot;
}

/// Mounts a tiny home page whose button (`open`) pushes the game screen, so leaving the
/// game has somewhere to go.
Future<WingyBot> pumpGameFromHome(
  WidgetTester tester,
  Services s, {
  WingyGame? game,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final g = game ?? seededGame();
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => GameScreen(game: g)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump(const Duration(milliseconds: 400));
  final bot = WingyBot(tester);
  await bot.waitForGame();
  return bot;
}

/// Drives the game through its widgets and reads state through the test IDs (used by
/// widget tests and the integration test).
class WingyBot {
  WingyBot(this.tester);
  final WidgetTester tester;

  WingyGame get game => tester
      .widget<GameWidget<WingyGame>>(find.byKey(TestIds.gameWidget))
      .game!;

  WingyRun get run => game.run;

  Future<void> waitForGame() async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (game.isLoaded && game.size.x > 10) return;
    }
    throw StateError('Game did not load');
  }

  /// Lets simulated time pass (pumpAndSettle never returns while the game loop runs).
  Future<void> wait(int milliseconds) async {
    for (var t = 0; t < milliseconds; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapField() async {
    await tester.tap(find.byKey(TestIds.gameField));
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// Semantics value of an ID such as `game.meter` or `game.dash.state`.
  String? value(Key key) =>
      tester.widget<Semantics>(find.byKey(key)).properties.value;

  String scoreText() =>
      tester.widget<Text>(find.byKey(TestIds.gameScore)).data!;

  /// Kills Wingy by dropping it on the ground and waits for the game over dialog.
  Future<void> crash() async {
    run.y = 600;
    run.vy = 700;
    await wait(1500);
  }
}
