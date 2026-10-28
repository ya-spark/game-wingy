/// Tuning constants for Wingy. Logical world units (u): the world is 360 u wide and 640 u
/// tall. Pure Dart: no Flutter, Flame or Android imports.
abstract final class WingyWorld {
  static const double width = 360;
  static const double height = 640;

  /// Ceiling is at y = 0, the ground strip starts at [groundY].
  static const double groundY = 584;

  /// Wingy's fixed x and hitbox radius.
  static const double mothX = 100;
  static const double mothRadius = 14;
  static const double startY = 292;

  /// Simulation step.
  static const double fixedDt = 1 / 120;

  static const double gravity = 1500;
  static const double flapVelocity = -430;
  static const double terminalVelocity = 700;

  static const double startSpeed = 140;
  static const double speedPerPass = 2;
  static const double maxSpeed = 220;

  static const double pairSpacing = 220;
  static const double spireWidth = 56;
  static const double firstPairDistance = 360;

  static const double startGapHeight = 210;
  static const double gapShrinkPerPair = 1.5;
  static const double gapFloor = 150;
  static const double gapOffsetMin = -20;
  static const double gapOffsetMax = 30;
  static const double breatherBonus = 60;
  static const double gapEdgeMargin = 40;
  static const double maxCenterDelta = 200;

  /// Downward center changes are limited a little more (125 u): a drop needs the moth to
  /// fall through the end of the previous gap, which is the one move that can become
  /// unwinnable at full speed if the last flap was badly timed.
  static const double maxDownDelta = 125;
  static const int breatherEvery = 7;
  static const int driftEvery = 10;
  static const int driftFromPair = 20;
  static const double driftAmplitude = 30;
  static const double driftPeriod = 2.0;

  static const double orbRadius = 10;
  static const double orbChance = 0.25;
  static const int maxMeter = 3;
  static const int runCoinCap = 40;

  /// Perfect pass: within the middle 30% of the gap height.
  static const double perfectFraction = 0.30;
  static const int bloomCap = 5;
  static const int dashPairPoints = 3;

  static const double dashDuration = 1.2;
  static const double dashGrace = 0.4;
  static const double dashSpeedFactor = 1.8;
  static const double dashMinY = 40;
  static const double dashMaxY = 544;

  static const double deathDuration = 0.6;
  static const double reviveInvulnerability = 2.0;
  static const double reviveClearDistance = 300;
  static const int maxRevives = 1;
}

/// Cosmetic palette, chosen from the score.
enum WingyPalette { dusk, aurora, midnight }

WingyPalette paletteForScore(int score) => score >= 60
    ? WingyPalette.midnight
    : (score >= 25 ? WingyPalette.aurora : WingyPalette.dusk);

enum Medal { none, bronze, silver, gold, prism }

Medal medalForScore(int score) => score >= 100
    ? Medal.prism
    : score >= 50
    ? Medal.gold
    : score >= 25
    ? Medal.silver
    : score >= 10
    ? Medal.bronze
    : Medal.none;

/// Coins granted at run end for [score]: 1 per 5 points (orb coins are added separately).
int scoreCoins(int score) => score ~/ 5;
