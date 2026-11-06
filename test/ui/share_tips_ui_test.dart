import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/app.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/core/save/save_data.dart';
import 'package:wingy/core/save/save_service.dart';
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
  // The tip dialog opens after the first frame.
  await tester.pump(const Duration(milliseconds: 400));
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

/// Save service whose `save` waits until [release] is called (a slow disk write).
class _GatedSaveService extends MemorySaveService {
  final _gate = Completer<void>();
  bool gated = false;
  void release() => _gate.complete();

  @override
  Future<void> save(SaveData d) async {
    if (gated) await _gate.future;
    await super.save(d);
  }
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

  testWidgets('settings.shareApp is visible with the default link mode and '
      'shares the high score message and link', (tester) async {
    final s = await buildFakeServices();
    final share = s.share as FakeShareService;
    expect(share.hasLink, isTrue);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final tile = find.byKey(TestIds.settingsShareApp, skipOffstage: false);
    expect(tile, findsOneWidget);
    tester.view.physicalSize = const Size(
      400,
      2000,
    ); // the whole list on screen
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('Try Wingy!\n')); // no best yet
    expect(share.sent.single.text, endsWith(s.config.shareLink!));
  });

  testWidgets('settings.shareApp is hidden when there is no link', (
    tester,
  ) async {
    final s = await buildFakeServices(share: FakeShareService());
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
    expect(
      share.sent.single.text,
      startsWith('This is my high score in Wingy: '),
    );
  });

  testWidgets('home tip dialog opens once per day and not again the same day', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    expect(find.byKey(TestIds.tipDontShow), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    // Same day: opening the app again shows nothing.
    await s.profile.onAppOpened();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);
    // Next day it is pending again.
    now = DateTime.utc(2026, 11, 6, 10);
    expect(s.profile.homeTipPending, isTrue);
  });

  testWidgets('no tip while a run is on screen: resume with the game on top', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(TestIds.homePlay));
    await frames(tester, 10);
    expect(s.inRun, isTrue);
    // A new day starts while the run is going, then the app comes back from the background.
    now = DateTime.utc(2026, 11, 6, 10);
    expect(s.profile.homeTipPending, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 10);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    // Nothing was queued: the tip is still pending, and the flag clears when the run is left.
    expect(s.profile.homeTipPending, isTrue);
  });

  testWidgets('no tip when Play is tapped while the tip is still being saved', (
    tester,
  ) async {
    final saves = _GatedSaveService();
    final s = await buildFakeServices(tips: true, profileSaves: saves);
    saves.gated = true; // the save that marks the tip as shown is slow
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    await tester.tap(find.byKey(TestIds.homePlay));
    await frames(tester, 10);
    saves.release();
    await frames(tester, 10);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(find.byKey(TestIds.gamePause), findsOneWidget);
  });

  testWidgets('the home page has no tip card in its layout', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tip of the day'), findsNothing);
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });

  testWidgets('no tip dialog when tips are off', (tester) async {
    final s = await buildFakeServices(); // tips off
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final sw = find.byKey(TestIds.settingsTips);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
    // The dialog was already shown today, so it stays away until tomorrow.
    expect(s.profile.homeTipPending, isFalse);
  });

  testWidgets('no tip in the game: not at game over, not in the pause dialog', (
    tester,
  ) async {
    final s = await buildFakeServices(tips: true);
    final game = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gamePause));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(find.byKey(TestIds.tipClose), findsNothing);
    await tester.tap(find.byKey(TestIds.gamePauseResume));
    await frames(tester, 80); // past the resume countdown

    await tester.tap(find.byKey(TestIds.gameReady), warnIfMissed: false);
    await killHero(tester, game);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipClose), findsNothing);
  });

  testWidgets('game over: panel layout and the eye button', (tester) async {
    final s = await buildFakeServices();
    await s.profile.setSound(false);
    final game = await pumpGame(tester, s);
    await tester.tap(find.byKey(TestIds.gameReady));
    await killHero(tester, game);

    final panel = find.byKey(TestIds.gameOverPanel);
    expect(panel, findsOneWidget);
    final rect = tester.getRect(panel);
    final share = tester.getRect(find.byKey(TestIds.gameOverShare));
    final score = tester.getRect(find.byKey(TestIds.gameOverScore));
    final again = tester.getRect(find.byKey(TestIds.gameOverRetry));
    final home = tester.getRect(find.byKey(TestIds.gameOverHome));
    final refill = tester.getRect(find.byKey(TestIds.gameOverRefill));
    final cont = tester.getRect(find.byKey(TestIds.gameOverRevive));
    // Share at the top left, above the score.
    expect(share.left, lessThan(rect.left + 40));
    expect(share.bottom, lessThan(score.top));
    // Play again and Home side by side, below the score.
    expect(again.top, greaterThan(score.bottom));
    expect(again.center.dy, closeTo(home.center.dy, 1));
    expect(again.right, lessThan(home.left));
    // Refill just above Continue, Continue last and the largest.
    expect(refill.bottom, lessThanOrEqualTo(cont.top));
    expect(refill.top, greaterThan(again.bottom));
    expect(cont.height, greaterThan(again.height));
    expect(cont.bottom, lessThan(rect.bottom));

    // The eye hides the panel (fade 0.2 s); the eye stays; a tap anywhere brings it back.
    final eye = find.byKey(TestIds.gameOverView);
    expect(eye, findsOneWidget);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: panel, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(), 1);
    await tester.tap(eye);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);
    expect(eye, findsOneWidget);
    expect(game.run.isDead, isTrue);
    await tester.tapAt(const Offset(200, 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
    // The eye button brings it back too.
    await tester.tap(eye);
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);
    await tester.tap(eye);
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
  });
}
