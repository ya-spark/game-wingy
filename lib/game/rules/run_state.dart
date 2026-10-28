import 'dart:math';

import 'gap_generator.dart';
import 'spire.dart';
import 'world.dart';

enum RunPhase { ready, playing, dead }

enum RunEventKind {
  flap,
  pass,
  perfect,
  orb,
  dashStart,
  dashEnd,
  shatter,
  hit,
  revive,
}

/// Something that happened during a step, for the view (sounds, floating text, haptics).
class RunEvent {
  const RunEvent(this.kind, {this.points = 0, this.streak = 0, this.bloom = 0});
  final RunEventKind kind;
  final int points;
  final int streak;
  final int bloom;
}

/// Totals of a finished run, fed into stats, challenges and achievements.
class RunSummary {
  const RunSummary({
    required this.score,
    required this.passes,
    required this.perfectPasses,
    required this.maxPerfectStreak,
    required this.orbs,
    required this.dashUses,
    required this.dashShatters,
    required this.bloomHits,
    required this.coins,
  });
  final int score;
  final int passes;
  final int perfectPasses;
  final int maxPerfectStreak;
  final int orbs;
  final int dashUses;
  final int dashShatters;
  final int bloomHits;

  /// Coins earned this run: orb coins (capped) plus 1 per 5 points.
  final int coins;
}

/// One run of Wingy. Pure Dart: time only comes from fixed [WingyWorld.fixedDt] steps and
/// randomness only from the injected [Random], so a seed plus a tap trace replays exactly.
class WingyRun {
  WingyRun({
    Random? random,
    this.bestScore = 0,
    int startMeter = 0,
    bool startPlaying = false,
  }) : generator = GapGenerator(random ?? Random()),
       meter = startMeter.clamp(0, WingyWorld.maxMeter) {
    _fill();
    if (startPlaying) begin();
  }

  final GapGenerator generator;
  final List<SpirePair> pairs = [];
  final List<RunEvent> _events = [];

  RunPhase phase = RunPhase.ready;
  bool paused = false;

  // Moth
  double y = WingyWorld.startY;
  double vy = 0;

  /// Seconds of simulated play time (stops when paused).
  double time = 0;
  double _acc = 0;

  // Score
  int score = 0;
  int bestScore;
  int pairsPassed = 0;
  int perfectStreak = 0;
  int maxPerfectStreak = 0;
  int perfectPasses = 0;
  int bloomHits = 0;
  int orbsCollected = 0;
  int runCoins = 0;
  int dashUses = 0;
  int dashShatters = 0;
  int lastBloom = 0;

  // Glow Dash
  int meter;
  double dashRemaining = 0;
  double graceRemaining = 0;

  // Death / revive
  int revivesUsed = 0;
  double invulnRemaining = 0;
  double deathElapsed = 0;

  bool get isDashing => dashRemaining > 0;
  bool get isInvulnerable => invulnRemaining > 0;
  bool get isPlaying => phase == RunPhase.playing;
  bool get isDead => phase == RunPhase.dead;

  /// Death fall/shake is over; show the game over dialog.
  bool get gameOverReady =>
      isDead && deathElapsed >= WingyWorld.deathDuration - 1e-9;

  bool get canRevive => isDead && revivesUsed < WingyWorld.maxRevives;

  /// Base scroll speed: 140 u/s, +2 per pair passed, capped at 220.
  double get scrollSpeed => min(
    WingyWorld.maxSpeed,
    WingyWorld.startSpeed + WingyWorld.speedPerPass * pairsPassed,
  );

  double get effectiveSpeed =>
      scrollSpeed * (isDashing ? WingyWorld.dashSpeedFactor : 1);

  bool get canDash =>
      isPlaying && !paused && meter >= WingyWorld.maxMeter && !isDashing;

  WingyPalette get palette => paletteForScore(score);

  /// Drains and returns events produced since the last call.
  List<RunEvent> drainEvents() {
    final e = List<RunEvent>.of(_events);
    _events.clear();
    return e;
  }

  /// First pair whose trailing edge Wingy has not passed yet.
  SpirePair? get nextPair {
    for (final p in pairs) {
      if (!p.passed) return p;
    }
    return null;
  }

  /// Starts the run without flapping (the first tap calls this then flaps).
  void begin() {
    if (phase == RunPhase.ready) phase = RunPhase.playing;
  }

  void pause() => paused = true;
  void resume() => paused = false;

  /// Flap: sets vertical velocity (does not add). The first flap starts the run.
  bool flap() {
    if (paused) return false;
    if (phase == RunPhase.ready) begin();
    if (phase != RunPhase.playing || isDashing) return false;
    vy = WingyWorld.flapVelocity;
    _events.add(const RunEvent(RunEventKind.flap));
    return true;
  }

  /// Starts a Glow Dash if the meter is full and none is running.
  bool startDash() {
    if (!canDash) return false;
    meter = 0;
    dashRemaining = WingyWorld.dashDuration;
    graceRemaining = 0;
    dashUses++;
    vy = 0;
    y = y.clamp(WingyWorld.dashMinY, WingyWorld.dashMaxY).toDouble();
    _events.add(const RunEvent(RunEventKind.dashStart));
    return true;
  }

  /// Gives the meter its three pips (Dash Refill at run start).
  void fillMeter() => meter = WingyWorld.maxMeter;

  /// Advances by [dt] real seconds using fixed steps.
  void advance(double dt) {
    _acc += min(dt, 0.1);
    while (_acc >= WingyWorld.fixedDt) {
      _acc -= WingyWorld.fixedDt;
      step();
    }
  }

  /// One fixed simulation step of 1/120 s.
  void step() {
    if (paused || phase == RunPhase.ready) return;
    const dt = WingyWorld.fixedDt;
    if (phase == RunPhase.dead) {
      _stepDead(dt);
      return;
    }
    time += dt;

    // Timers.
    if (dashRemaining > 0) {
      dashRemaining -= dt;
      if (dashRemaining <= 0) {
        dashRemaining = 0;
        graceRemaining = WingyWorld.dashGrace;
        vy = 0;
        _events.add(const RunEvent(RunEventKind.dashEnd));
      }
    } else if (graceRemaining > 0) {
      graceRemaining = max(0, graceRemaining - dt);
    }
    if (invulnRemaining > 0) invulnRemaining = max(0, invulnRemaining - dt);

    // Physics.
    if (isDashing) {
      vy = 0;
      y = y.clamp(WingyWorld.dashMinY, WingyWorld.dashMaxY).toDouble();
    } else {
      vy = min(vy + WingyWorld.gravity * dt, WingyWorld.terminalVelocity);
      y += vy * dt;
    }

    // Scroll.
    final dx = effectiveSpeed * dt;
    for (final p in pairs) {
      p.x -= dx;
    }
    pairs.removeWhere((p) => p.right < -60);
    _fill();

    // Bounds.
    const r = WingyWorld.mothRadius;
    if (isInvulnerable) {
      if (y < r) {
        y = r;
        vy = max(vy, 0);
      }
      if (y > WingyWorld.groundY - r - 1) {
        y = WingyWorld.groundY - r - 1;
        vy = min(vy, 0);
      }
    } else if (y >= WingyWorld.groundY - r || y <= r) {
      _die();
      return;
    }

    // Spires.
    final immune = isDashing || graceRemaining > 0 || isInvulnerable;
    for (final p in pairs) {
      if (p.shattered) continue;
      if (isDashing && p.hitsColumn(WingyWorld.mothX, r)) {
        p.shattered = true;
        _events.add(const RunEvent(RunEventKind.shatter));
        continue;
      }
      if (!immune && p.hitsCircle(WingyWorld.mothX, y, r, time)) {
        _die();
        return;
      }
    }

    // Orbs.
    for (final p in pairs) {
      if (!p.hasOrb || p.orbTaken) continue;
      final dxo = p.x - WingyWorld.mothX;
      final dyo = p.centerYAt(time) - y;
      final reach = r + WingyWorld.orbRadius;
      if (dxo * dxo + dyo * dyo <= reach * reach) _takeOrb(p);
    }

    // Passes.
    for (final p in pairs) {
      if (!p.passed && WingyWorld.mothX > p.right) _pass(p);
    }
  }

  void _takeOrb(SpirePair p) {
    p.orbTaken = true;
    orbsCollected++;
    score += 1;
    meter = min(WingyWorld.maxMeter, meter + 1);
    if (runCoins < WingyWorld.runCoinCap) runCoins++;
    _touchBest();
    _events.add(const RunEvent(RunEventKind.orb, points: 1));
  }

  void _pass(SpirePair p) {
    p.passed = true;
    pairsPassed++;
    if (p.shattered) {
      score += WingyWorld.dashPairPoints;
      dashShatters++;
      _touchBest();
      _events.add(
        const RunEvent(
          RunEventKind.pass,
          points: WingyWorld.dashPairPoints,
          streak: 0,
        ),
      );
      return;
    }
    final offset = (y - p.centerYAt(time)).abs();
    final perfect = offset <= p.gapHeight * WingyWorld.perfectFraction / 2;
    var points = 1;
    var bloom = 0;
    if (perfect) {
      perfectStreak++;
      perfectPasses++;
      maxPerfectStreak = max(maxPerfectStreak, perfectStreak);
      points = 2;
      if (perfectStreak >= 3) {
        bloom = min(perfectStreak - 2, WingyWorld.bloomCap);
        points += bloom;
        if (bloom >= 3) bloomHits++;
      }
    } else {
      perfectStreak = 0;
    }
    lastBloom = bloom;
    score += points;
    _touchBest();
    _events.add(
      RunEvent(
        perfect ? RunEventKind.perfect : RunEventKind.pass,
        points: points,
        streak: perfectStreak,
        bloom: bloom,
      ),
    );
  }

  void _touchBest() {
    if (score > bestScore) bestScore = score;
  }

  void _die() {
    phase = RunPhase.dead;
    deathElapsed = 0;
    dashRemaining = 0;
    graceRemaining = 0;
    _events.add(const RunEvent(RunEventKind.hit));
  }

  void _stepDead(double dt) {
    deathElapsed += dt;
    vy = min(vy + WingyWorld.gravity * dt, WingyWorld.terminalVelocity);
    y = min(y + vy * dt, WingyWorld.groundY - WingyWorld.mothRadius);
  }

  /// One revive per run: Wingy returns to the center of the nearest upcoming gap, spires
  /// within 300 u ahead are removed, 2 s of invulnerability. Score and streak are kept.
  bool revive() {
    if (!canRevive) return false;
    revivesUsed++;
    final upcoming =
        pairs
            .where((p) => p.right > WingyWorld.mothX - WingyWorld.mothRadius)
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    y = upcoming.isEmpty ? WingyWorld.startY : upcoming.first.centerYAt(time);
    vy = 0;
    pairs.removeWhere(
      (p) =>
          p.right > WingyWorld.mothX - WingyWorld.mothRadius &&
          p.x <= WingyWorld.mothX + WingyWorld.reviveClearDistance,
    );
    _fill();
    invulnRemaining = WingyWorld.reviveInvulnerability;
    dashRemaining = 0;
    graceRemaining = 0;
    deathElapsed = 0;
    phase = RunPhase.playing;
    _events.add(const RunEvent(RunEventKind.revive));
    return true;
  }

  RunSummary summary() => RunSummary(
    score: score,
    passes: pairsPassed,
    perfectPasses: perfectPasses,
    maxPerfectStreak: maxPerfectStreak,
    orbs: orbsCollected,
    dashUses: dashUses,
    dashShatters: dashShatters,
    bloomHits: bloomHits,
    coins: runCoins + scoreCoins(score),
  );

  /// Keeps pairs generated until one lies beyond the right edge.
  void _fill() {
    while (pairs.isEmpty ||
        pairs.last.x < WingyWorld.width + WingyWorld.pairSpacing) {
      final x = pairs.isEmpty
          ? WingyWorld.mothX + WingyWorld.firstPairDistance
          : pairs.last.x + WingyWorld.pairSpacing;
      pairs.add(generator.next(x));
    }
  }
}
