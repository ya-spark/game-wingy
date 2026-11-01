import 'package:flutter/material.dart';

import '../core/services.dart';
import 'challenges_screen.dart';
import 'daily_reward_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'test_ids.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServicesScope.of(context).profile.onAppOpened();
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      body: KidBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final claimable = profile.challenges.any((c) => c.claimable);
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 14,
                          children: [
                            const Bobbing(
                              child: Text(
                                '\u{1F54A}\u{FE0F}',
                                style: TextStyle(fontSize: 72),
                              ),
                            ),
                            Text(
                              s.config.displayName,
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: KidColors.ink,
                                        offset: Offset(0, 4),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                KeyedSubtree(
                                  key: TestIds.homeCoins,
                                  child: StatChip(
                                    icon: Icons.monetization_on,
                                    label: '${profile.data.coins}',
                                    color: Colors.amber,
                                  ),
                                ),
                                KeyedSubtree(
                                  key: TestIds.homeBestScore,
                                  child: StatChip(
                                    icon: Icons.emoji_events,
                                    label: 'Best ${profile.data.bestScore}',
                                  ),
                                ),
                                if (s.config.retention.streaks)
                                  KeyedSubtree(
                                    key: TestIds.homeStreak,
                                    child: StatChip(
                                      icon: Icons.local_fire_department,
                                      label: '${profile.displayStreak}',
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            MenuButton(
                              key: TestIds.homePlay,
                              label: 'Play',
                              icon: Icons.play_arrow,
                              primary: true,
                              emoji: '\u{1F680}',
                              onPressed: () => _open(const GameScreen()),
                            ),
                            if (s.config.retention.dailyReward)
                              MenuButton(
                                key: TestIds.homeDailyReward,
                                label: 'Daily reward',
                                icon: Icons.card_giftcard,
                                emoji: '\u{1F381}',
                                color: KidColors.coral,
                                badge: profile.dailyRewardAvailable,
                                onPressed: () =>
                                    _open(const DailyRewardScreen()),
                              ),
                            if (s.config.retention.dailyChallenges ||
                                s.config.retention.achievements)
                              MenuButton(
                                key: TestIds.homeChallenges,
                                label: 'Challenges',
                                icon: Icons.flag,
                                emoji: '\u{1F3C6}',
                                color: KidColors.grape,
                                badge: claimable,
                                onPressed: () =>
                                    _open(const ChallengesScreen()),
                              ),
                            MenuButton(
                              key: TestIds.homeShop,
                              label: 'Shop',
                              icon: Icons.shopping_cart,
                              emoji: '\u{1F6CD}\u{FE0F}',
                              color: KidColors.sun,
                              onPressed: () => _open(const ShopScreen()),
                            ),
                            MenuButton(
                              key: TestIds.homeSettings,
                              label: 'Settings',
                              icon: Icons.settings,
                              emoji: '\u2699\u{FE0F}',
                              color: Colors.blueGrey,
                              onPressed: () => _open(const SettingsScreen()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  KeyedSubtree(
                    key: TestIds.homeBanner,
                    child: s.ads.buildBanner(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
