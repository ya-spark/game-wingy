import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/profile/profile_store.dart';
import '../core/retention/economy.dart';
import '../core/services.dart';
import '../game/flame/wingy_game.dart';
import '../game/rules/run_state.dart';
import '../game/rules/world.dart';
import 'test_ids.dart';

/// `--dart-define=WINGY_SEED=<int>` fixes the gap generator (bots, repeatable runs).
const int _seedDefine = int.fromEnvironment('WINGY_SEED', defaultValue: -1);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded generator).
  final WingyGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  WingyGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;

  /// A Dash Refill was chosen for the next run; it is spent when that run is created.
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
    // Backgrounding pauses a running game; the player resumes with the 3-2-1 countdown.
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _pause() {
    final game = _game;
    if (game == null || !game.run.isPlaying || game.run.paused) return;
    game.pause();
  }

  WingyGame _ensureGame(Services s) {
    final existing = _game;
    if (existing != null) return existing;
    final game =
        widget.game ??
        WingyGame(
          bestScore: s.profile.data.bestScore,
          seed: _seedDefine >= 0 ? _seedDefine : null,
          reduceMotion: s.profile.data.reduceMotion,
        );
    // Flame updates run during the build phase, so UI work is deferred to after the frame.
    game.onChanged = () {
      if (!mounted) return;
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    };
    game.onGameOver = () =>
        WidgetsBinding.instance.addPostFrameCallback((_) => _showGameOver(s));
    game.onEvent = (e) {
      if (!s.profile.data.vibrationOn) return;
      if (e.kind == RunEventKind.perfect) HapticFeedback.lightImpact();
      if (e.kind == RunEventKind.hit) HapticFeedback.mediumImpact();
    };
    return _game = game;
  }

  Future<void> _finishGame(Services s) async {
    if (_recorded) return;
    _recorded = true;
    final r = _game!.run.summary();
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: r.score,
        passes: r.passes,
        maxPerfectStreak: r.maxPerfectStreak,
        orbs: r.orbs,
        dashUses: r.dashUses,
        dashShatters: r.dashShatters,
        bloomHits: r.bloomHits,
        coins: r.coins,
      ),
    );
    await s.leaderboard.submitScore(
      s.config.playGames.leaderboardHighScore,
      r.score,
    );
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': r.score});
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

  // ---- Dash Refill ---------------------------------------------------------

  /// Arms a Dash Refill for the next run. With no stock this opens the refill sheet
  /// (buy with coins or watch an ad). Returns true when a refill is armed.
  Future<bool> _requestRefill(Services s) async {
    if (_refillArmed) return true;
    if (s.profile.dashRefills <= 0) {
      final got = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => _RefillSheet(services: s),
      );
      if (got != true || !mounted) return false;
    }
    _refillArmed = true;
    return true;
  }

  Future<void> _useRefillNow(Services s) async {
    if (!await _requestRefill(s)) return;
    _refillArmed = false;
    if (await s.profile.consumeDashRefill()) _game!.fillMeter();
  }

  Future<void> _startNextRun(Services s) async {
    var meter = 0;
    if (_refillArmed && await s.profile.consumeDashRefill()) {
      meter = WingyWorld.maxMeter;
    }
    _refillArmed = false;
    _recorded = false;
    _game!.restart(startMeter: meter);
  }

  // ---- game over -----------------------------------------------------------

  Future<void> _showGameOver(Services s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final run = game.run;
    final medal = medalForScore(run.score);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: TestIds.gameOverDialog,
        title: const Text('Game over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${run.score}', key: TestIds.gameOverScore, style: _big),
            Text(
              'Best ${max(run.bestScore, run.score)}',
              key: TestIds.gameOverBest,
            ),
            Text(
              medal == Medal.none
                  ? 'No medal yet'
                  : '${medal.name[0].toUpperCase()}${medal.name.substring(1)} medal',
              key: TestIds.gameOverMedal,
            ),
          ],
        ),
        actions: [
          if (run.canRevive)
            FilledButton.icon(
              key: TestIds.gameOverRevive,
              icon: const Icon(Icons.smart_display),
              label: const Text('Revive (watch ad)'),
              onPressed: () => Navigator.pop(ctx, 'revive'),
            ),
          TextButton.icon(
            key: TestIds.gameOverRefill,
            icon: Icon(
              _refillArmed ? Icons.check_circle : Icons.bolt,
              size: 18,
            ),
            label: Text(
              _refillArmed
                  ? 'Dash Refill ready'
                  : 'Dash Refill (${s.profile.dashRefills})',
            ),
            onPressed: _refillArmed ? null : () => Navigator.pop(ctx, 'refill'),
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
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        final earned = await s.ads.showRewarded(AdPlacement.revive);
        if (!mounted) return;
        if (earned && game.revive()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _showGameOver(s);
      case 'refill':
        await _requestRefill(s);
        if (mounted) _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        await _startNextRun(s);
      default:
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _quit(Services s) async {
    final game = _game!;
    if (game.run.phase != RunPhase.ready) await _finishGame(s);
    if (mounted) Navigator.of(context).pop();
  }

  static const TextStyle _big = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
  );

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final game = _ensureGame(s);
    final run = game.run;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final best = max(run.bestScore, run.score);
    final showPauseMenu =
        run.paused && !game.isCountingDown && run.phase != RunPhase.dead;

    return Scaffold(
      backgroundColor: const Color(0xFF14103A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget<WingyGame>(key: TestIds.gameWidget, game: game),
          // Tap anywhere on the play field flaps.
          Listener(
            key: TestIds.gameField,
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => game.tap(),
            child: SizedBox.expand(
              child: run.phase == RunPhase.ready
                  ? const _ReadyHint()
                  : const SizedBox.shrink(),
            ),
          ),
          // Score pill, best and Bloom chip (taps pass through to the field).
          Positioned(
            top: top + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: _ScoreHud(
                score: run.score,
                best: best,
                streak: run.perfectStreak,
              ),
            ),
          ),
          Positioned(
            top: top + 6,
            left: 8,
            child: IconButton.filledTonal(
              key: TestIds.gameBack,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _quit(s),
            ),
          ),
          Positioned(
            top: top + 6,
            right: 8,
            child: IconButton.filledTonal(
              key: TestIds.gamePause,
              icon: const Icon(Icons.pause),
              onPressed: run.isDead ? null : game.pause,
            ),
          ),
          Positioned(
            top: top + 62,
            left: 16,
            child: _Meter(pips: run.meter),
          ),
          if (run.phase == RunPhase.ready)
            Positioned(
              bottom: bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: OutlinedButton.icon(
                  key: TestIds.gameReadyRefill,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text('Dash Refill (${s.profile.dashRefills})'),
                  onPressed: () => _useRefillNow(s),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: bottom + 24,
            child: Semantics(
              key: TestIds.gameDashState,
              identifier: 'game.dash.state',
              value: game.dashState,
              child: _DashButton(state: game.dashState, onPressed: game.dash),
            ),
          ),
          if (game.isCountingDown)
            IgnorePointer(
              child: Center(
                child: Text(
                  '${game.countdown.ceil()}',
                  key: TestIds.gameCountdown,
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (showPauseMenu)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xAA000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 12,
                        children: [
                          Text(
                            'Paused',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          FilledButton(
                            key: TestIds.gamePauseResume,
                            onPressed: game.beginResume,
                            child: const Text('Resume'),
                          ),
                          OutlinedButton(
                            key: TestIds.gamePauseQuit,
                            onPressed: () => _quit(s),
                            child: const Text('Quit'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadyHint extends StatelessWidget {
  const _ReadyHint();

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, 0.35),
    child: Container(
      key: TestIds.gameReady,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Tap to flap',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
    ),
  );
}

/// Score in a glowing pill with the best score under it and the Bloom chip beside it.
class _ScoreHud extends StatelessWidget {
  const _ScoreHud({
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 120),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFFFE27A), width: 1.5),
                color: const Color(0x22FFFFFF),
                boxShadow: const [
                  BoxShadow(color: Color(0x66FFE27A), blurRadius: 22),
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
            if (streak >= 2) ...[
              const SizedBox(width: 8),
              Container(
                key: TestIds.gameStreak,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCCC050E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Bloom x$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$best',
          key: TestIds.gameBest,
          style: const TextStyle(color: Color(0xFFFFE27A), fontSize: 13),
        ),
      ],
    );
  }
}

/// Three glow-orb pips; Semantics value is the pip count.
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
        spacing: 6,
        children: [
          for (var i = 0; i < WingyWorld.maxMeter; i++)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < pips
                    ? const Color(0xFF7FF7FF)
                    : const Color(0x33FFFFFF),
                border: Border.all(color: const Color(0xFF7FF7FF)),
                boxShadow: i < pips
                    ? const [BoxShadow(color: Color(0x887FF7FF), blurRadius: 8)]
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ready = state == 'ready';
    final active = state == 'active';
    return SizedBox(
      width: 72,
      height: 72,
      child: FilledButton(
        key: TestIds.gameDash,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: active
              ? const Color(0xFFFFE27A)
              : (ready ? const Color(0xFF7FF7FF) : const Color(0x33FFFFFF)),
          foregroundColor: const Color(0xFF14103A),
        ),
        onPressed: ready ? onPressed : null,
        child: const Icon(Icons.bolt, size: 36),
      ),
    );
  }
}

/// Bottom sheet offered when a Dash Refill is wanted but none is in stock.
class _RefillSheet extends StatefulWidget {
  const _RefillSheet({required this.services});
  final Services services;

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    final ok = await widget.services.profile.buyDashRefill();
    if (mounted) Navigator.pop(context, ok);
  }

  Future<void> _watch() async {
    setState(() => _busy = true);
    final s = widget.services;
    final earned = await s.ads.showRewarded(AdPlacement.dashRefill);
    final ok = earned && await s.profile.grantAdRefill();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not available. Try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.profile;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text('Dash Refill', style: Theme.of(context).textTheme.titleLarge),
            const Text('Start the next run with a full Glow Dash meter.'),
            FilledButton.icon(
              key: TestIds.gameRefillCoins,
              icon: const Icon(Icons.monetization_on),
              label: Text('Buy for ${Economy.dashRefillCost} coins'),
              onPressed: !_busy && p.data.coins >= Economy.dashRefillCost
                  ? _buy
                  : null,
            ),
            OutlinedButton.icon(
              key: TestIds.gameRefillAd,
              icon: const Icon(Icons.smart_display),
              label: Text('Watch an ad (${p.adRefillsLeftToday} left today)'),
              onPressed: !_busy && p.adRefillsLeftToday > 0 ? _watch : null,
            ),
          ],
        ),
      ),
    );
  }
}
