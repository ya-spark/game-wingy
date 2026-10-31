/// World constants for Wingy (logical units "u"). Pure Dart: no Flutter, Flame or Android
/// imports, so the rules run on the VM and stay portable.
abstract final class WingyWorld {
  static const double width = 360;
  static const double height = 640;
  static const double ceilingY = 0;
  static const double groundY = 584;

  /// Fixed simulation step.
  static const double step = 1 / 120;

  static const double heroX = 100;
  static const double heroRadius = 14;
  static const double heroStartY = 292;

  static const double gravity = 1500;
  static const double flapVelocity = -430;
  static const double terminalVelocity = 700;

  static const double startSpeed = 140;
  static const double speedPerPass = 2;
  static const double maxSpeed = 220;

  static const double spireWidth = 56;
  static const double pairSpacing = 220;
  static const double firstPairX = 360;

  static const double baseGapStart = 210;
  static const double gapShrinkPerPair = 1.5;
  static const double gapFloor = 150;
  static const double gapOffsetMin = -20;
  static const double gapOffsetMax = 30;
  static const double gapEdgeMargin = 40;
  static const double maxCenterDelta = 200;
  static const double breatherBonus = 60;
  static const int breatherEvery = 7;

  static const int driftEvery = 10;
  static const int driftFromScore = 20;
  static const double driftAmplitude = 30;
  static const double driftPeriod = 2.0;

  static const double orbRadius = 10;
  static const int orbChanceDenominator = 4;
  static const double orbRandomChance = 0.25;
  static const int runCoinCap = 40;

  static const double perfectFraction = 0.30;
  static const int bloomMax = 5;
  static const int dashPairPoints = 3;

  static const int meterMax = 3;
  static const double dashDuration = 1.2;
  static const double dashGrace = 0.4;

  /// Seconds of normal-speed travel kept clear ahead of Wingy when lightning ends.
  static const double dashExitBuffer = 1.75;
  static const double dashSpeedFactor = 1.8;
  static const double dashMinY = 40;
  static const double dashMaxY = 544;

  static const double deathAnimation = 0.6;
  static const int maxRevives = 3;
  static const double reviveClearDistance = 300;
  static const double reviveInvulnerability = 2.0;
}

enum Palette { dusk, aurora, midnight }

/// Cosmetic palette by score.
Palette paletteForScore(int score) {
  if (score >= 60) return Palette.midnight;
  if (score >= 25) return Palette.aurora;
  return Palette.dusk;
}

enum Medal { none, bronze, silver, gold, prism }

Medal medalForScore(int score) {
  if (score >= 100) return Medal.prism;
  if (score >= 50) return Medal.gold;
  if (score >= 25) return Medal.silver;
  if (score >= 10) return Medal.bronze;
  return Medal.none;
}
