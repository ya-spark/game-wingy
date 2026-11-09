import 'package:flutter/material.dart';

import '../core/services.dart';
import '../game/flame/wingy_painter.dart';
import '../game/rules/world.dart';
import 'home_hero.dart';
import 'more_games_screen.dart';
import 'routes.dart';
import 'test_ids.dart';
import 'tip_dialog.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTip());
  }

  /// True only when Home is the page on top and no run is on screen.
  bool _homeIsOnTop(Services s) =>
      mounted && !s.inRun && ModalRoute.of(context)?.isCurrent == true;

  bool _tipBusy = false;

  /// Opens the tip dialog once per day, when the home page is shown and nothing else is on top.
  /// Never queued: when the guard blocks it nothing happens, and the next Home visit tries again.
  Future<void> _maybeShowTip() async {
    if (_tipBusy || !mounted) return;
    final s = ServicesScope.of(context);
    if (!_homeIsOnTop(s) || !s.profile.homeTipPending) return;
    _tipBusy = true;
    try {
      final text = s.tips.tipOfTheDay(s.profile.today);
      await s.profile.markHomeTipShown();
      // The save is async: a run may have started meanwhile, so check again before opening.
      if (!mounted || !_homeIsOnTop(s)) return;
      await showTipDialog(context, text: text);
    } finally {
      _tipBusy = false;
    }
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
      _maybeShowTip();
    }
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: WingyPainter.paletteColors(
                paletteOrder[profile.data.paletteStart % paletteOrder.length],
              ),
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: ListenableBuilder(
                  listenable: profile,
                  builder: (context, _) {
                    final claimable = profile.challenges.any(
                      (c) => c.claimable,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final offer = !profile.data.adsRemoved;
                              final (heroH, gap) = homeLayout(
                                box.maxHeight,
                                removeAdsOffer: offer,
                              );
                              return Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: gap,
                                    children: [
                                      HomeHero(height: heroH),
                                      Text(
                                        s.config.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayMedium
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
                                              leading: const CoinIcon(),
                                              label: '${profile.data.coins}',
                                              color: Colors.amber,
                                            ),
                                          ),
                                          KeyedSubtree(
                                            key: TestIds.homeBestScore,
                                            child: StatChip(
                                              icon: Icons.emoji_events,
                                              label:
                                                  'Best ${profile.data.bestScore}',
                                            ),
                                          ),
                                          if (s.config.retention.streaks)
                                            KeyedSubtree(
                                              key: TestIds.homeStreak,
                                              child: StatChip(
                                                icon:
                                                    Icons.local_fire_department,
                                                label:
                                                    '${profile.displayStreak}',
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (offer)
                                        RemoveAdsPill(
                                          key: TestIds.homeRemoveAds,
                                          onPressed: () =>
                                              _open(AppRoutes.shop),
                                        ),
                                      const SizedBox(height: 8),
                                      MenuButton(
                                        key: TestIds.homePlay,
                                        label: 'Play',
                                        icon: Icons.play_arrow,
                                        primary: true,
                                        emoji: '\u{1F680}',
                                        onPressed: () => _open(AppRoutes.play),
                                      ),
                                      HomeGrid(
                                        children: [
                                          if (s.config.retention.dailyReward)
                                            MenuButton(
                                              compact: true,
                                              key: TestIds.homeDailyReward,
                                              label: 'Daily reward',
                                              icon: Icons.card_giftcard,
                                              emoji: '\u{1F381}',
                                              color: KidColors.coral,
                                              badge:
                                                  profile.dailyRewardAvailable,
                                              onPressed: () =>
                                                  _open(AppRoutes.dailyReward),
                                            ),
                                          if (s
                                                  .config
                                                  .retention
                                                  .dailyChallenges ||
                                              s.config.retention.achievements)
                                            MenuButton(
                                              compact: true,
                                              key: TestIds.homeChallenges,
                                              label: 'Challenges',
                                              icon: Icons.flag,
                                              emoji: '\u{1F3C6}',
                                              color: KidColors.grape,
                                              badge: claimable,
                                              onPressed: () =>
                                                  _open(AppRoutes.challenges),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        if (s.config.visibleMoreGames.isNotEmpty)
                          HomeIconButton(
                            key: TestIds.homeMoreGames,
                            icon: Icons.apps,
                            label: 'More games',
                            colors: const [KidColors.ocean, Color(0xFF1E6FD9)],
                            onPressed: () => openMoreGames(context),
                          ),
                        HomeIconButton(
                          key: TestIds.homeShop,
                          icon: Icons.shopping_basket,
                          label: 'Shop',
                          colors: const [KidColors.sun, Color(0xFFE0A100)],
                          onPressed: () => _open(AppRoutes.shop),
                        ),
                        HomeIconButton(
                          key: TestIds.homeSettings,
                          icon: Icons.settings,
                          label: 'Settings',
                          colors: [Colors.blueGrey.shade300, Colors.blueGrey],
                          onPressed: () => _open(AppRoutes.settings),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
