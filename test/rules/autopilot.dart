import 'package:wingy/game/rules/run_state.dart';
import 'package:wingy/game/rules/world.dart';

/// Reference autopilot: flap whenever Wingy sinks to a flap level inside the next gap. Near
/// the end of a gap it biases the level towards the side the following gap lies on, like a
/// player would, so the 200 u center changes stay reachable at full speed.
bool autopilotWants(WingyRun run) {
  // Keep aiming at a gap until Wingy's body has fully cleared its spires.
  final p = run.pairs
      .where((p) => p.right + WingyWorld.mothRadius + 2 > WingyWorld.mothX)
      .firstOrNull;
  if (p == null) return run.y >= WingyWorld.startY + 30;
  final c = p.centerYAt(run.time);
  final index = run.pairs.indexOf(p);
  final next = index + 1 < run.pairs.length
      ? run.pairs[index + 1].baseCenterY
      : c;
  // Near the end of a gap, flap at the side the following gap lies on.
  final leaving = p.right - WingyWorld.mothX < 100;
  final level = !leaving
      ? 30.0
      : next > c + 40
      ? 48.0
      : next < c - 40
      ? 10.0
      : 30.0;
  return run.y >= c + level;
}

/// Plays until [pairs] pairs are passed, the run dies, or [maxSteps] elapse.
/// Returns the run.
WingyRun playAutopilot(
  WingyRun run, {
  int pairs = 500,
  int maxSteps = 8000000,
}) {
  run.begin();
  for (var i = 0; i < maxSteps && run.isPlaying; i++) {
    if (autopilotWants(run)) run.flap();
    run.step();
    if (run.pairsPassed >= pairs) break;
  }
  return run;
}

/// Holds Wingy at [y] with zero velocity each step (for scoring tests).
void holdAt(WingyRun run, double Function() y, {int maxSteps = 400000}) {
  for (var i = 0; i < maxSteps && run.isPlaying; i++) {
    run.y = y();
    run.vy = 0;
    run.step();
  }
}
