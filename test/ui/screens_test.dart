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

/// pumpAndSettle never returns while the Flame game loop is running.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(TestIds.shopBuy('remove_ads')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads')));
    await tester.pumpAndSettle();
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads')), findsNothing);
    await tester.ensureVisible(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(TestIds.settingsHaptics));
    await tester.pumpAndSettle();
    expect(s.profile.data.vibrationOn, isFalse);
    await tester.tap(find.byKey(TestIds.settingsReduceMotion));
    await tester.pumpAndSettle();
    expect(s.profile.data.reduceMotion, isTrue);
    // Play Games is off in app.config.yaml, so its row is hidden.
    expect(find.byKey(TestIds.settingsPlayGames), findsNothing);
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
