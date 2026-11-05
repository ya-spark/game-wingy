import 'package:flutter/material.dart';
import 'package:wingy/app.dart';
import 'package:wingy/core/retention/daily_reward.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/ui/home_hero.dart';
import 'package:wingy/ui/test_ids.dart';
import 'package:wingy/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

/// pumpAndSettle never returns while the Flame game loop is running.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Taps a product's buy button and answers the parent gate correctly.
Future<void> buyWithGate(WidgetTester tester, Services s, String id) async {
  await tester.ensureVisible(find.byKey(TestIds.shopBuy(id)));
  await settle(tester);
  await tester.tap(find.byKey(TestIds.shopBuy(id)));
  await settle(tester);
  await tester.enterText(
    find.byKey(TestIds.gateAnswer),
    '${s.parentGate.question.answer}',
  );
  await tester.tap(find.byKey(TestIds.gateSubmit));
  await settle(tester);
}

void main() {
  testWidgets('home shows the main menu', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    for (final k in [
      TestIds.homePlay,
      TestIds.homeDailyReward,
      TestIds.homeChallenges,
      TestIds.homeShop,
      TestIds.homeSettings,
      TestIds.homeCoins,
      TestIds.homeBestScore,
      TestIds.homeBanner,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
  });

  testWidgets(
    'home hero animates, pauses when covered, still on reduce motion',
    (tester) async {
      final s = await buildFakeServices();
      await pumpApp(tester, s);
      HomeHeroState hero() => tester.state<HomeHeroState>(
        find.byType(HomeHero, skipOffstage: false),
      );
      expect(find.byKey(TestIds.homeHero), findsOneWidget);
      expect(hero().running, isTrue);
      await tester.tap(find.byKey(TestIds.homeSettings));
      await tester.pumpAndSettle();
      expect(hero().running, isFalse);
      await tester.pageBack();
      await settle(tester); // the hero never settles
      expect(hero().running, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(hero().running, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(hero().running, isTrue);
      await s.profile.setReduceMotion(true);
      await tester.pumpWidget(GameApp(services: s));
      await tester.pump();
      expect(find.byKey(TestIds.homeHero), findsOneWidget);
      expect(hero().running, isFalse);
    },
  );

  testWidgets('daily reward screen: claim adds coins and disables the button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeDailyReward));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.dailyDay(6)), findsOneWidget);
    await tester.tap(find.byKey(TestIds.dailyClaim));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, DailyRewardEngine.coinsByDay[0]);
    final btn = tester.widget<FilledButton>(find.byKey(TestIds.dailyClaim));
    expect(btn.onPressed, isNull);
  });

  testWidgets(
    'challenges screen lists three daily challenges and achievements',
    (tester) async {
      final s = await buildFakeServices();
      await pumpApp(tester, s);
      await tester.tap(find.byKey(TestIds.homeChallenges));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(TestIds.challengeTile(i)), findsOneWidget);
      }
      // The list is lazy and the daily challenge text varies per day, so the
      // achievements may start below the fold: scroll instead of assuming.
      final tile = find.byKey(TestIds.achievementTile('ach_first_flight'));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tile, findsOneWidget);
    },
  );

  testWidgets('shop: buying remove ads marks it owned and disables ads', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await settle(tester);
    // The shop lists Remove Ads and all three coin packs.
    for (final id in [
      'remove_ads_all',
      'coins_500',
      'coins_1500',
      'coins_4000',
    ]) {
      expect(find.byKey(TestIds.shopBuy(id)), findsOneWidget, reason: id);
    }
    await buyWithGate(tester, s, 'remove_ads_all');
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads_all')), findsNothing);
    await buyWithGate(tester, s, 'coins_500');
    expect(s.profile.data.coins, 500);
  });

  testWidgets('shop: a purchase is blocked until the gate is answered', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await settle(tester);
    expect(find.byKey(TestIds.gateDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gateCancel));
    await settle(tester);
    expect(s.profile.data.coins, 0);
    expect(find.byKey(TestIds.gateDialog), findsNothing);
  });

  testWidgets('shop: wings are bought with coins and equipped', (tester) async {
    final s = await buildFakeServices();
    await s.profile.addCoins(350);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await settle(tester);
    // Too expensive: the buy button is disabled.
    await tester.ensureVisible(find.byKey(TestIds.shopSkinBuy('firefly')));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.shopSkinBuy('firefly')));
    await settle(tester);
    expect(s.profile.ownsSkin('firefly'), isFalse);
    expect(s.profile.data.coins, 350);
    await tester.ensureVisible(find.byKey(TestIds.shopSkinBuy('butterfly')));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.shopSkinBuy('butterfly')));
    await settle(tester);
    expect(s.profile.data.coins, 50);
    expect(s.profile.equippedSkin, 'butterfly');
    await tester.ensureVisible(find.byKey(TestIds.shopSkinEquip('moth')));
    await settle(tester);
    await tester.tap(find.byKey(TestIds.shopSkinEquip('moth')));
    await settle(tester);
    expect(s.profile.equippedSkin, 'moth');
  });

  testWidgets('the coin icon replaces the old icon on home', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    expect(find.byType(CoinIcon), findsWidgets);
    expect(find.byIcon(Icons.monetization_on), findsNothing);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    await tester.tap(find.byKey(TestIds.settingsHaptics));
    await tester.pumpAndSettle();
    expect(s.profile.data.vibrationOn, isFalse);
    await tester.tap(find.byKey(TestIds.settingsReduceMotion));
    await tester.pumpAndSettle();
    expect(s.profile.data.reduceMotion, isTrue);
    // Play Games is off in app.config.yaml, so its row is hidden.
    expect(find.byKey(TestIds.settingsPlayGames), findsNothing);
  });

  testWidgets('sound and hand settings persist to the profile', (tester) async {
    final s = await buildFakeServices();
    expect(s.profile.data.masterVolume, 1.0);
    expect(s.profile.data.ambience, 'night');
    expect(s.profile.data.voiceOn, isTrue);
    expect(s.profile.data.sfxOn, isTrue);
    expect(s.profile.data.leftHanded, isFalse);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsVoice));
    await tester.pumpAndSettle();
    expect(s.profile.data.voiceOn, isFalse);
    await tester.tap(find.byKey(TestIds.settingsSfx));
    await tester.pumpAndSettle();
    expect(s.profile.data.sfxOn, isFalse);
    await tester.drag(
      find.byKey(TestIds.settingsVolume),
      const Offset(-4000, 0),
    );
    await tester.pumpAndSettle();
    expect(s.profile.data.masterVolume, 0.0);
    await tester.tap(find.byKey(TestIds.settingsAmbience));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heartbeat').last);
    await tester.pumpAndSettle();
    expect(s.profile.data.ambience, 'heartbeat');
    await tester.ensureVisible(find.byKey(TestIds.settingsHand));
    await tester.tap(find.text('Left'));
    await tester.pumpAndSettle();
    expect(s.profile.data.leftHanded, isTrue);
  });

  testWidgets('play opens the game; back returns home with no banner in game', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await settle(tester);
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
    expect(find.byKey(TestIds.homeBanner), findsNothing);
    expect(find.byKey(const Key('game.banner')), findsNothing);
    await tester.tap(find.byKey(TestIds.gameBack));
    await settle(tester);
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
    expect(find.byKey(TestIds.homeBanner), findsOneWidget);
  });
}
