import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show Color;

import '../rules/run_state.dart';
import '../rules/world.dart';
import 'wingy_view.dart';

/// Flame host for Wingy. All rules live in [WingyRun] (pure Dart); this class advances the
/// simulation with real frame time, forwards taps, and notifies the UI.
class WingyGame extends FlameGame {
  WingyGame({
    this.bestScore = 0,
    this.seed,
    this.reduceMotion = false,
    this.runFactory,
  }) {
    run = _create(0);
  }

  /// Best score at the start of the session, shown in the HUD.
  int bestScore;

  /// Fixed generator seed (`--dart-define=WINGY_SEED=<int>`), or null for random runs.
  final int? seed;

  /// Disables screen shake and parallax.
  bool reduceMotion;

  /// Test hook: builds the run (seeded generator, prepared state).
  final WingyRun Function(int bestScore, int startMeter)? runFactory;

  late WingyRun run;
  late WingyView view;

  /// Notifies the UI that something the HUD shows has changed.
  void Function()? onChanged;

  /// Called once per death, when the fall/shake is over (show the game over dialog).
  void Function()? onGameOver;

  /// Called for every simulation event (haptics, sounds).
  void Function(RunEvent event)? onEvent;

  /// Seconds left of the 3-2-1 countdown after a resume (the run stays paused meanwhile).
  double countdown = 0;

  /// Total scrolled distance (visual parallax only).
  double distance = 0;

  /// Wall-clock time for animations (stars, hover, flicker).
  double clock = 0;

  bool _gameOverSent = false;
  int _lastSignature = 0;

  WingyRun _create(int startMeter) =>
      runFactory?.call(bestScore, startMeter) ??
      WingyRun(
        random: seed == null ? Random() : Random(seed),
        bestScore: bestScore,
        startMeter: startMeter,
      );

  @override
  Color backgroundColor() => const Color(0xFF14103A);

  @override
  Future<void> onLoad() async {
    view = WingyView();
    await add(view);
  }

  bool get isCountingDown => countdown > 0;

  /// Tap anywhere on the field.
  void tap() {
    if (isCountingDown) return; // the first tap after a resume is swallowed
    if (run.flap()) _afterInput();
  }

  /// Glow Dash button.
  void dash() {
    if (isCountingDown) return;
    if (run.startDash()) _afterInput();
  }

  void pause() {
    countdown = 0;
    run.pause();
    _notify(force: true);
  }

  /// Starts the 3-2-1 countdown; the run resumes when it reaches zero.
  void beginResume() {
    if (!run.paused) return;
    countdown = 3;
    _notify(force: true);
  }

  /// Fresh run. [startMeter] 3 starts with a full Glow Dash meter (Dash Refill).
  void restart({int startMeter = 0}) {
    bestScore = max(bestScore, run.bestScore);
    run = _create(startMeter);
    _gameOverSent = false;
    countdown = 0;
    distance = 0;
    if (isLoaded) view.reset();
    _notify(force: true);
  }

  /// Fills the Glow Dash meter of a run that has not started yet.
  void fillMeter() {
    run.fillMeter();
    _notify(force: true);
  }

  bool revive() {
    final ok = run.revive();
    if (ok) {
      _gameOverSent = false;
      _notify(force: true);
    }
    return ok;
  }

  void _afterInput() {
    _handleEvents();
    _notify();
  }

  @override
  void update(double dt) {
    super.update(dt);
    clock += dt;
    if (countdown > 0) {
      countdown = max(0, countdown - dt);
      if (countdown == 0) run.resume();
      _notify(force: true);
      return;
    }
    if (run.paused) return;
    run.advance(dt);
    if (run.isPlaying) distance += run.effectiveSpeed * min(dt, 0.1);
    _handleEvents();
    if (run.gameOverReady && !_gameOverSent) {
      _gameOverSent = true;
      onGameOver?.call();
    }
    _notify();
  }

  void _handleEvents() {
    for (final e in run.drainEvents()) {
      if (isLoaded) view.onEvent(e);
      onEvent?.call(e);
    }
  }

  /// Everything the HUD shows; the UI is rebuilt only when this changes.
  int get signature => Object.hash(
    run.score,
    run.bestScore,
    run.perfectStreak,
    run.meter,
    run.isDashing,
    run.phase,
    run.paused,
    countdown.ceil(),
    run.canRevive,
    run.gameOverReady,
  );

  void _notify({bool force = false}) {
    final s = signature;
    if (force || s != _lastSignature) {
      _lastSignature = s;
      onChanged?.call();
    }
  }

  /// Dash button state for the HUD and tests: off, ready or active.
  String get dashState => run.isDashing
      ? 'active'
      : (run.canDash && !isCountingDown ? 'ready' : 'off');

  double get worldScale =>
      min(size.x / WingyWorld.width, size.y / WingyWorld.height);
}
