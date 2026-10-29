import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import '../game/flame/wingy_game.dart';
import '../game/rules/wingy_run.dart';
import '../game/rules/world.dart';
import 'test_ids.dart';

const int _wingySeed = int.fromEnvironment('WINGY_SEED', defaultValue: -1);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded run).
  final WingyGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  WingyGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;
  bool _pauseOpen = false;
  bool _refillArmed = false;

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
    if (state != AppLifecycleState.resumed) _pause();
  }

  WingyRun _newRun(Services s, {int meter = 0}) => WingyRun(
    random: _wingySeed >= 0 ? Random(_wingySeed) : null,
    bestScore: s.profile.data.bestScore,
    startMeter: meter,
  );

  WingyGame _ensureGame(Services s) {
    final existing = _game;
    if (existing != null) return existing;
    final game =
        widget.game ??
        WingyGame(run: _newRun(s), reduceMotion: s.profile.data.reduceMotion);
    game.onChanged = () {
      if (mounted) setState(() {});
    };
    game.onEvent = (e) {
      if (!s.profile.data.vibrationOn) return;
      if (e.type == RunEventType.perfect) HapticFeedback.lightImpact();
      if (e.type == RunEventType.hit) HapticFeedback.mediumImpact();
    };
    game.onGameOver = () => _showGameOver(s);
    return _game = game;
  }

  // ---- run bookkeeping ------------------------------------------------------

  Future<void> _finishGame(Services s) async {
    if (_recorded) return;
    final run = _game!.run;
    if (run.phase == RunPhase.ready) return;
    _recorded = true;
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: run.score,
        pairsPassed: run.pairsPassed,
        perfectStreak: run.maxStreak,
        orbs: run.orbsCollected,
        dashUses: run.dashUses,
        dashShattered: run.dashShattered,
        bloomHits: run.bloomHits,
        coins: run.coins + run.scoreCoins,
      ),
    );
    await s.leaderboard.submitScore(
      s.config.playGames.leaderboardHighScore,
      run.score,
    );
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': run.score});
    if (unlocked.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')} '
            '(+${unlocked.fold<int>(0, (n, a) => n + a.reward)} coins)',
          ),
        ),
      );
    }
  }

  Future<void> _quit(Services s) async {
    await _finishGame(s);
    if (mounted) Navigator.of(context).pop();
  }

  // ---- pause ---------------------------------------------------------------

  Future<void> _pause() async {
    final game = _game;
    if (game == null || !mounted || _pauseOpen || _dialogOpen) return;
    if (game.run.isDead) return;
    final s = ServicesScope.of(context);
    game.pause();
    _pauseOpen = true;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paused'),
        actions: [
          TextButton(
            key: TestIds.gamePauseQuit,
            onPressed: () => Navigator.pop(ctx, 'quit'),
            child: const Text('Quit'),
          ),
          FilledButton(
            key: TestIds.gamePauseResume,
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    _pauseOpen = false;
    if (!mounted) return;
    if (action == 'quit') {
      await _quit(s);
    } else {
      game.resume();
    }
  }

  // ---- game over -------------------------------------------------------------

  static String _medalName(Medal m) => switch (m) {
    Medal.none => 'No medal',
    Medal.bronze => 'Bronze',
    Medal.silver => 'Silver',
    Medal.gold => 'Gold',
    Medal.prism => 'Prism',
  };

  Future<void> _showGameOver(Services s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final run = game.run;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          key: TestIds.gameOverDialog,
          title: const Text('Game over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${run.score}',
                key: TestIds.gameOverScore,
                style: Theme.of(ctx).textTheme.displaySmall,
              ),
              Text('Best ${run.bestScore}', key: TestIds.gameOverBest),
              Text(_medalName(run.medal), key: TestIds.gameOverMedal),
            ],
          ),
          actions: [
            if (run.canRevive)
              FilledButton.icon(
                key: TestIds.gameOverRevive,
                icon: const Icon(Icons.smart_display),
                label: Text('Revive (watch ad) · ${run.revivesLeft} left'),
                onPressed: () => Navigator.pop(ctx, 'revive'),
              ),
            OutlinedButton.icon(
              key: TestIds.gameOverRefill,
              icon: const Icon(Icons.bolt),
              label: Text(
                _refillArmed
                    ? 'Dash ready'
                    : 'Dash Refill (${s.profile.dashRefills})',
              ),
              onPressed: _refillArmed
                  ? null
                  : () async {
                      if (s.profile.dashRefills > 0) {
                        setDialog(() => _refillArmed = true);
                        return;
                      }
                      final got = await showModalBottomSheet<bool>(
                        context: ctx,
                        builder: (_) => _RefillSheet(services: s),
                      );
                      if (got == true) setDialog(() => _refillArmed = true);
                    },
            ),
            TextButton(
              key: TestIds.gameOverRetry,
              onPressed: () => Navigator.pop(ctx, 'retry'),
              child: const Text('Play again'),
            ),
            TextButton(
              key: TestIds.gameOverHome,
              onPressed: () => Navigator.pop(ctx, 'home'),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        final earned = await s.ads.showRewarded(AdPlacement.revive);
        if (!mounted) return;
        if (earned && run.revive()) {
          game.revived();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        var meter = 0;
        if (_refillArmed && await s.profile.consumeDashRefill()) meter = 3;
        _refillArmed = false;
        _recorded = false;
        game.newRun(_newRun(s, meter: meter));
      default:
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (mounted) Navigator.of(context).pop();
    }
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final game = _ensureGame(s);
    game.reduceMotion = s.profile.data.reduceMotion;
    final run = game.run;
    final dashState = run.isDashing
        ? 'active'
        : (run.canDash ? 'ready' : 'off');
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              key: TestIds.gameField,
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => game.tap(),
              child: GameWidget<WingyGame>(key: TestIds.gameWidget, game: game),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton.filledTonal(
                        key: TestIds.gameBack,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _quit(s),
                      ),
                      const SizedBox(height: 8),
                      _Meter(pips: run.meter),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: _ScoreArea(
                      score: run.score,
                      best: run.bestScore,
                      streak: run.perfectStreak,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    key: TestIds.gamePause,
                    icon: const Icon(Icons.pause),
                    onPressed: _pause,
                  ),
                ),
                Positioned(
                  bottom: 28,
                  right: 20,
                  child: Semantics(
                    key: TestIds.gameDashState,
                    identifier: 'game.dash.state',
                    value: dashState,
                    child: _DashButton(
                      state: dashState,
                      onPressed: run.canDash && game.countdown == 0
                          ? game.dash
                          : null,
                    ),
                  ),
                ),
                if (run.phase == RunPhase.ready)
                  Center(
                    child: GestureDetector(
                      key: TestIds.gameReady,
                      behavior: HitTestBehavior.opaque,
                      onTap: game.tap,
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'TAP TO FLAP',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 22,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (game.countdownNumber > 0)
                  Center(
                    child: IgnorePointer(
                      child: Text(
                        '${game.countdownNumber}',
                        key: TestIds.gameCountdown,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 96,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Score in a glowing pill with best score and Bloom streak chip.
class _ScoreArea extends StatelessWidget {
  const _ScoreArea({
    required this.score,
    required this.best,
    required this.streak,
  });
  final int score;
  final int best;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 120),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFB896FF), width: 1.5),
                color: const Color(0x22FFFFFF),
                boxShadow: const [
                  BoxShadow(color: Color(0x66B896FF), blurRadius: 22),
                ],
              ),
              child: Text(
                '$score',
                key: TestIds.gameScore,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Semantics(
              key: TestIds.gameStreak,
              identifier: 'game.streak',
              value: '$streak',
              child: streak >= 2
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        avatar: const Icon(
                          Icons.local_florist,
                          size: 16,
                          color: Color(0xFFFFE066),
                        ),
                        label: Text('x$streak'),
                      ),
                    )
                  : const SizedBox(width: 0, height: 0),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$best',
          key: TestIds.gameBest,
          style: const TextStyle(color: Color(0xFFFFE066), fontSize: 13),
        ),
      ],
    );
  }
}

/// Three-pip Glow Dash meter.
class _Meter extends StatelessWidget {
  const _Meter({required this.pips});
  final int pips;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: TestIds.gameMeter,
      identifier: 'game.meter',
      value: '$pips',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < WingyWorld.meterMax; i++)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < pips
                    ? const Color(0xFF7CF5FF)
                    : const Color(0x33FFFFFF),
                boxShadow: i < pips
                    ? const [BoxShadow(color: Color(0xAA7CF5FF), blurRadius: 8)]
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashButton extends StatelessWidget {
  const _DashButton({required this.state, required this.onPressed});
  final String state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ready = state == 'ready';
    final active = state == 'active';
    return SizedBox(
      width: 76,
      height: 76,
      child: FilledButton(
        key: TestIds.gameDash,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: active
              ? const Color(0xFFFFE066)
              : (ready ? const Color(0xFF7CF5FF) : const Color(0x33FFFFFF)),
          foregroundColor: const Color(0xFF1B1446),
          disabledBackgroundColor: active
              ? const Color(0xFFFFE066)
              : const Color(0x33FFFFFF),
          disabledForegroundColor: active
              ? const Color(0xFF1B1446)
              : Colors.white38,
        ),
        onPressed: onPressed,
        child: const Icon(Icons.bolt, size: 40),
      ),
    );
  }
}

/// Bottom sheet offering a Dash Refill for coins or for a rewarded ad.
class _RefillSheet extends StatelessWidget {
  const _RefillSheet({required this.services});
  final Services services;

  @override
  Widget build(BuildContext context) {
    final p = services.profile;
    return SafeArea(
      key: TestIds.gameRefillSheet,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              'Start the next run with a full Glow Dash',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FilledButton.icon(
              key: TestIds.gameRefillCoins,
              icon: const Icon(Icons.monetization_on),
              label: Text('Use ${ProfileStore.dashRefillCoinCost} coins'),
              onPressed: p.data.coins >= ProfileStore.dashRefillCoinCost
                  ? () async {
                      final ok = await p.buyDashRefillWithCoins();
                      if (context.mounted) Navigator.pop(context, ok);
                    }
                  : null,
            ),
            OutlinedButton.icon(
              key: TestIds.gameRefillAd,
              icon: const Icon(Icons.smart_display),
              label: Text('Watch an ad (${p.adRefillsLeft} left today)'),
              onPressed: p.adRefillsLeft > 0
                  ? () async {
                      final earned = await services.ads.showRewarded(
                        AdPlacement.dashRefill,
                      );
                      final ok = earned && await p.grantAdDashRefill();
                      if (context.mounted) Navigator.pop(context, ok);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
