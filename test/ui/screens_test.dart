import 'package:flutter/material.dart';
import 'package:wingy/app.dart';
import 'package:wingy/core/retention/daily_reward.dart';
import 'package:wingy/core/services.dart';
import 'package:wingy/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
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
      expect(
        find.byKey(TestIds.achievementTile('ach_first_flight')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shop: buying remove ads marks it owned and disables ads', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads')));
    await tester.pumpAndSettle();
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads')), findsNothing);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 500);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    expect(find.byKey(TestIds.settingsPlayGames), findsOneWidget);
  });

  testWidgets('settings: haptics and reduce motion toggles persist', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsHaptics));
    await tester.pumpAndSettle();
    expect(s.profile.data.vibrationOn, isFalse);
    await tester.tap(find.byKey(TestIds.settingsReduceMotion));
    await tester.pumpAndSettle();
    expect(s.profile.data.reduceMotion, isTrue);
  });

  testWidgets('shop: coins buy a Dash Refill and a streak freeze', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.addCoins(150);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuyRefill));
    await tester.pumpAndSettle();
    expect(s.profile.dashRefills, 1);
    expect(s.profile.data.coins, 110);
    await tester.tap(find.byKey(TestIds.shopBuyFreeze));
    await tester.pumpAndSettle();
    expect(s.profile.data.streak.freezes, 1);
    expect(s.profile.data.coins, 10);
    // Not enough coins left: both buttons are disabled.
    expect(
      tester.widget<FilledButton>(find.byKey(TestIds.shopBuyRefill)).onPressed,
      isNull,
    );
  });

  testWidgets('home Play opens the game and Back returns to the menu', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.gameField), findsOneWidget);
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    await tester.tap(find.byKey(TestIds.gameBack));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
