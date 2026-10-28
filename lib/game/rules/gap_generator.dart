import 'dart:math';

import 'spire.dart';
import 'world.dart';

/// Produces the endless sequence of spire pairs from an injected [Random]. Each pair always
/// consumes the same number of random values, so a seed gives one fixed sequence.
class GapGenerator {
  GapGenerator(this.random);

  final Random random;
  int _next = 0;
  double _prevCenter = WingyWorld.startY;
  bool _prevDrifting = false;

  /// Number of pairs generated so far.
  int get generated => _next;

  /// Base gap height for the pair with 0-based [index]: 210 u shrinking 1.5 u per pair.
  static double baseHeight(int index) => max(
    WingyWorld.gapFloor,
    WingyWorld.startGapHeight - WingyWorld.gapShrinkPerPair * index,
  );

  static bool isWide(int number) => number % WingyWorld.breatherEvery == 0;

  static bool isDrifting(int number) =>
      number % WingyWorld.driftEvery == 0 && number >= WingyWorld.driftFromPair;

  static bool isForcedOrb(int number) => number % 4 == 3;

  /// Next pair, placed with its center at [x].
  SpirePair next(double x) {
    final index = _next++;
    final number = index + 1;
    final base = baseHeight(index);
    final rOffset = random.nextDouble();
    final rCenter = random.nextDouble();
    final rOrb = random.nextDouble();

    final wide = isWide(number);
    final height = wide
        ? base + WingyWorld.breatherBonus
        : max(
            WingyWorld.gapFloor,
            base +
                WingyWorld.gapOffsetMin +
                rOffset * (WingyWorld.gapOffsetMax - WingyWorld.gapOffsetMin),
          );
    final drifting = isDrifting(number);

    // The gap (including its drift) always fits between ceiling and ground margins.
    final margin =
        WingyWorld.gapEdgeMargin +
        height / 2 +
        (drifting ? WingyWorld.driftAmplitude : 0);
    final lo = max(margin, _prevCenter - WingyWorld.maxCenterDelta);
    // Drifting gaps move +/-30 u, so drops into or out of one are limited further.
    final down =
        WingyWorld.maxDownDelta -
        (drifting ? WingyWorld.driftAmplitude : 0) -
        (_prevDrifting ? WingyWorld.driftAmplitude : 0);
    final hi = max(lo, min(WingyWorld.groundY - margin, _prevCenter + down));
    final center = lo + rCenter * (hi - lo);
    _prevCenter = center;
    _prevDrifting = drifting;

    // Orbs: pairs 3, 7, 11, ... always; a 25% chance only on pairs whose neighbours can
    // never hold an orb (number % 4 == 1), so two orbs are never adjacent.
    final orb =
        isForcedOrb(number) || (number % 4 == 1 && rOrb < WingyWorld.orbChance);

    return SpirePair(
      index: index,
      x: x,
      baseCenterY: center,
      gapHeight: height,
      drifting: drifting,
      wide: wide,
      hasOrb: orb,
    );
  }
}
