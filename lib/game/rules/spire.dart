import 'dart:math';

import 'world.dart';

/// One top+bottom spire pair. [x] is the horizontal center in screen units and moves left as
/// the world scrolls.
class SpirePair {
  SpirePair({
    required this.index,
    required this.x,
    required this.baseCenterY,
    required this.gapHeight,
    this.drifting = false,
    this.wide = false,
    this.hasOrb = false,
  });

  /// 0-based index in generation order.
  final int index;
  double x;
  final double baseCenterY;
  final double gapHeight;
  final bool drifting;

  /// "Wide breather" pair (every 7th).
  final bool wide;
  final bool hasOrb;

  bool passed = false;
  bool shattered = false;
  bool orbTaken = false;

  /// 1-based number of this pair.
  int get number => index + 1;

  double get left => x - WingyWorld.spireWidth / 2;
  double get right => x + WingyWorld.spireWidth / 2;

  /// Gap center at run time [t] seconds (drifting gaps oscillate).
  double centerYAt(double t) => drifting
      ? baseCenterY +
            WingyWorld.driftAmplitude * sin(2 * pi * t / WingyWorld.driftPeriod)
      : baseCenterY;

  double gapTopAt(double t) => centerYAt(t) - gapHeight / 2;
  double gapBottomAt(double t) => centerYAt(t) + gapHeight / 2;

  /// Circle at ([cx], radius [r]) overlaps this pair's column horizontally.
  bool hitsColumn(double cx, double r) => cx + r > left && cx - r < right;

  /// Circle at ([cx],[cy]) with [r] touches the top or bottom spire at time [t].
  bool hitsCircle(double cx, double cy, double r, double t) {
    if (cx + r <= left || cx - r >= right) return false;
    // Horizontal overlap with the spire column; the circle is safe only inside the gap.
    final top = gapTopAt(t);
    final bottom = gapBottomAt(t);
    return _circleRect(cx, cy, r, left, 0, right, top) ||
        _circleRect(cx, cy, r, left, bottom, right, WingyWorld.groundY);
  }

  static bool _circleRect(
    double cx,
    double cy,
    double r,
    double l,
    double t,
    double rt,
    double b,
  ) {
    final nx = cx.clamp(l, rt);
    final ny = cy.clamp(t, b);
    final dx = cx - nx;
    final dy = cy - ny;
    return dx * dx + dy * dy < r * r;
  }
}
