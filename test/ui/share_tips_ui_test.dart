import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/app.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/core/share/share_service.dart';
import 'package:wingy/game/flame/wingy_game.dart';
import 'package:wingy/game/rules/wingy_run.dart';
import 'package:wingy/game/rules/world.dart';
import 'package:wingy/ui/game_screen.dart';
import 'package:wingy/ui/share_card.dart';
import 'package:wingy/ui/test_ids.dart';

import '../helpers/fake_services.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

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

Future<void> killHero(WidgetTester tester, WingyGame g) async {
  g.run.invulnTimer = 0;
  g.run.y = 600;
  await frames(tester, 23);
}

void main() {
  testWidgets('share card renders to a non-empty PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: const ShareCard(
            data: ShareCardData(
              gameName: 'Wingy',
              headline: 'Score',
              big: '42',
              best: 99,
              palette: Palette.aurora,
              medal: 'Gold',
            ),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(
      () => boundaryToPng(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    // PNG signature.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('settings.shareApp is hidden while the link flag is off', (
    tester,
  ) async {
    final s = await buildFakeServices();
    expect(s.config.share.appLinkEnabled, isFalse);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    expect(
      find.byKey(TestIds.settingsShareApp, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(TestIds.settingsTips, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('game over share button shares the score text', (tester) async {
    final share = FakeShareService();
    final s = await buildFakeServices(share: share);
    await s.profile.setSound(false); // no audio plugin under test
    final game = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, game);
    expect(find.byKey(TestIds.gameOverShare), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRefill), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverShare));
    // Capture needs a real frame callback and real async image encoding.
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I scored '));
  });

  testWidgets('home tip shows once per day and closing keeps it hidden', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.hintDue('perfect'), isFalse);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final sw = find.byKey(TestIds.settingsTips);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
    expect(s.profile.hintDue('perfect'), isTrue);
    // The home tip was closed today, so it stays away until tomorrow.
    expect(s.profile.homeTipPending, isFalse);
  });

  testWidgets('game over tip shows on every 2nd game over', (tester) async {
    final s = await buildFakeServices(tips: true);
    final game = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, game);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsNothing);

    await tester.tap(find.byKey(TestIds.gameOverRetry));
    await frames(tester, 4);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, game);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsOneWidget);

    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
  });

  testWidgets('pause tip needs 3 s of pause', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gamePause));
    await tester.pump();
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(TestIds.tipPause), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.tipPause), findsOneWidget);
  });

  testWidgets('one-time hint shows once, for 4 s', (tester) async {
    final s = await buildFakeServices(tips: true);
    final game = await pumpGame(tester, s);
    expect(find.byKey(TestIds.tipHint), findsNothing);
    game.run.meter = WingyWorld.meterMax;
    game.run.phase = RunPhase.playing;
    game.run.y = 300;
    game.run.vy = 0;
    await frames(tester, 3);
    expect(find.byKey(TestIds.tipHint), findsOneWidget);
    expect(s.profile.hintDue('glow_dash'), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byKey(TestIds.tipHint), findsNothing);
    // Never again.
    game.run.meter = 0;
    await frames(tester, 2);
    game.run.meter = WingyWorld.meterMax;
    game.run.y = 300;
    game.run.vy = 0;
    await frames(tester, 3);
    expect(find.byKey(TestIds.tipHint), findsNothing);
  });
}
