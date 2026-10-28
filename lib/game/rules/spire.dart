import 'dart:math';

import 'world.dart';

/// A top+bottom spire pair with a gap. [x] is the horizontal center (screen units).
class SpirePair {
  SpirePair({
    required this.number,
    required this.x,
    required this.baseCenterY,
    required this.gapHeight,
    required this.drifting,
    required this.hasOrb,
  });

  /// 1-based index of this pair in the run.
  final int number;
  double x;
  final double baseCenterY;
  final double gapHeight;
  final bool drifting;

  /// Seconds since spawn (advances only while the simulation runs).
  double age = 0;
  bool passed = false;
  bool shattered = false;

  /// A glow orb sits in the middle of the gap.
  final bool hasOrb;
  bool orbCollected = false;

  double get left => x - WingyWorld.spireWidth / 2;
  double get right => x + WingyWorld.spireWidth / 2;

  double get centerY => centerAt(age);

  double centerAt(double t) {
    if (!drifting) return baseCenterY;
    return baseCenterY +
        WingyWorld.driftAmplitude * sin(2 * pi * t / WingyWorld.driftPeriod);
  }

  double get gapTop => centerY - gapHeight / 2;
  double get gapBottom => centerY + gapHeight / 2;
}
