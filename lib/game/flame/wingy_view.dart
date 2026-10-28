import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextAlign, TextPainter, TextSpan, TextStyle, FontWeight, TextDirection;

import '../rules/run_state.dart';
import '../rules/spire.dart';
import '../rules/world.dart';
import 'wingy_game.dart';

class _FloatText {
  _FloatText(this.text, this.x, this.y, this.color, this.size);
  final String text;
  final double x;
  double y;
  final Color color;
  final double size;
  double age = 0;
}

class _Shard {
  _Shard(this.x, this.y, this.vx, this.vy, this.spin);
  double x;
  double y;
  final double vx;
  final double vy;
  final double spin;
  double age = 0;
}

/// Draws the whole world with Canvas shapes (no image assets): twilight gradient, stars,
/// parallax ridges, crystal spires, glow orbs, mushrooms and the moth. Reads the simulation
/// from [WingyGame.run]; it never changes game state.
class WingyView extends PositionComponent with HasGameReference<WingyGame> {
  static const _palettes = <WingyPalette, (Color, Color)>{
    WingyPalette.dusk: (Color(0xFF1A1450), Color(0xFF7A3FA8)),
    WingyPalette.aurora: (Color(0xFF0A3A4A), Color(0xFF2E8B88)),
    WingyPalette.midnight: (Color(0xFF05061C), Color(0xFF241A5C)),
  };

  Color _top = _palettes[WingyPalette.dusk]!.$1;
  Color _bottom = _palettes[WingyPalette.dusk]!.$2;

  final List<_FloatText> _texts = [];
  final List<_Shard> _shards = [];
  final Set<SpirePair> _shattered = {};
  late final List<(double, double, double)> _stars = _makeStars();

  double _shake = 0;
  double _flapAge = 1;
  final Paint _paint = Paint();

  static List<(double, double, double)> _makeStars() {
    final r = Random(7);
    return [
      for (var i = 0; i < 46; i++)
        (
          r.nextDouble() * WingyWorld.width,
          r.nextDouble() * 420,
          r.nextDouble() * 2 * pi,
        ),
    ];
  }

  void reset() {
    _texts.clear();
    _shards.clear();
    _shattered.clear();
    _shake = 0;
    _flapAge = 1;
  }

  void onEvent(RunEvent e) {
    final run = game.run;
    switch (e.kind) {
      case RunEventKind.flap:
        _flapAge = 0;
      case RunEventKind.pass:
      case RunEventKind.perfect:
        final bloom = e.bloom > 0 ? ' +${e.bloom}' : '';
        _texts.add(
          _FloatText(
            '+${e.points - e.bloom}${e.bloom > 0 ? ' Bloom$bloom' : ''}',
            WingyWorld.mothX + 30,
            run.y - 24,
            e.kind == RunEventKind.perfect
                ? const Color(0xFFFFE27A)
                : const Color(0xFFFFFFFF),
            e.kind == RunEventKind.perfect ? 20 : 16,
          ),
        );
      case RunEventKind.orb:
        _texts.add(
          _FloatText(
            '+1',
            WingyWorld.mothX,
            run.y - 28,
            const Color(0xFF7FF7FF),
            16,
          ),
        );
      case RunEventKind.hit:
        if (!game.reduceMotion) _shake = 0.25;
      case RunEventKind.dashStart:
      case RunEventKind.dashEnd:
      case RunEventKind.shatter:
      case RunEventKind.revive:
        break;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    _flapAge += dt;
    if (_shake > 0) _shake = max(0, _shake - dt);
    for (final t in _texts) {
      t.age += dt;
      t.y -= 40 * dt;
    }
    _texts.removeWhere((t) => t.age > 0.8);
    for (final s in _shards) {
      s.age += dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _shards.removeWhere((s) => s.age > 0.5);

    // Spawn shards for pairs the Glow Dash just shattered.
    final run = game.run;
    for (final p in run.pairs) {
      if (p.shattered && _shattered.add(p)) _spawnShards(p, run.time);
    }
    _shattered.removeWhere((p) => !run.pairs.contains(p));

    // Palette colors drift slowly towards the target palette.
    final target = _palettes[run.palette]!;
    final k = min(1.0, dt * 0.8);
    _top = Color.lerp(_top, target.$1, k)!;
    _bottom = Color.lerp(_bottom, target.$2, k)!;
  }

  void _spawnShards(SpirePair p, double t) {
    final r = Random(p.index);
    for (var i = 0; i < 6; i++) {
      final top = i < 3;
      final y = top
          ? p.gapTopAt(t) - 40 - i * 30
          : p.gapBottomAt(t) + 40 + (i - 3) * 30;
      _shards.add(
        _Shard(
          p.x + (r.nextDouble() - 0.5) * 30,
          y,
          (r.nextDouble() - 0.5) * 120,
          (top ? -1 : 1) * (20 + r.nextDouble() * 80),
          (r.nextDouble() - 0.5) * 6,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final scale = game.worldScale;
    final ox = (size.x - WingyWorld.width * scale) / 2;
    final oy = (size.y - WingyWorld.height * scale) / 2;
    final run = game.run;

    // Background fills the whole view, not only the 360x640 world.
    _paint
      ..shader = Gradient.linear(Offset.zero, Offset(0, size.y), [
        _top,
        _bottom,
      ])
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _paint);
    _paint.shader = null;

    canvas.save();
    if (_shake > 0) {
      final m = _shake / 0.25 * 6;
      canvas.translate(sin(_shake * 90) * m, cos(_shake * 70) * m);
    }
    canvas.translate(ox, oy);
    canvas.scale(scale);

    final parallax = game.reduceMotion ? 0.0 : 1.0;
    _drawStars(canvas);
    _drawRidge(
      canvas,
      game.distance * 0.08 * parallax,
      330,
      90,
      const Color(0x445B3FA0),
    );
    _drawMist(canvas, game.distance * 0.15 * parallax);
    _drawRidge(
      canvas,
      game.distance * 0.25 * parallax,
      410,
      60,
      const Color(0x663A2A80),
    );
    _drawRocks(canvas, game.distance * 0.4 * parallax);

    for (final p in run.pairs) {
      if (p.shattered) continue;
      _drawSpire(canvas, p, run.time);
    }
    for (final p in run.pairs) {
      if (p.hasOrb && !p.orbTaken) _drawOrb(canvas, p.x, p.centerYAt(run.time));
    }
    _drawGround(canvas, game.distance);
    _drawShards(canvas);
    _drawMoth(canvas);
    _drawTexts(canvas);
    canvas.restore();
  }

  // ---- background ---------------------------------------------------------

  void _drawStars(Canvas canvas) {
    for (final s in _stars) {
      final a = 0.35 + 0.35 * sin(game.clock * 0.9 + s.$3);
      _paint.color = Color.fromARGB(
        (a * 255).round().clamp(0, 255),
        255,
        255,
        255,
      );
      canvas.drawCircle(Offset(s.$1, s.$2), 1.2, _paint);
    }
  }

  void _drawRidge(
    Canvas canvas,
    double shift,
    double base,
    double amp,
    Color c,
  ) {
    final path = Path()..moveTo(-20, WingyWorld.groundY);
    for (var x = -20.0; x <= WingyWorld.width + 20; x += 10) {
      final w = x + shift;
      final y = base - amp * (0.5 + 0.5 * sin(w * 0.021) * cos(w * 0.007 + 1));
      path.lineTo(x, y);
    }
    path
      ..lineTo(WingyWorld.width + 20, WingyWorld.groundY)
      ..close();
    _paint.color = c;
    canvas.drawPath(path, _paint);
  }

  void _drawMist(Canvas canvas, double shift) {
    final dx = shift % 160;
    for (var i = -1; i < 4; i++) {
      final rect = Rect.fromCenter(
        center: Offset(i * 160 - dx + 80, 450),
        width: 220,
        height: 46,
      );
      _paint.color = const Color(0x1AFFFFFF);
      canvas.drawOval(rect, _paint);
    }
  }

  void _drawRocks(Canvas canvas, double shift) {
    const spacing = 190.0;
    final dx = shift % spacing;
    for (var i = -1; i < 3; i++) {
      final cx = i * spacing - dx + 60;
      final cy = 150.0 + ((i + (shift ~/ spacing)) % 3) * 70;
      _paint.color = const Color(0x55120B30);
      final path = Path()
        ..moveTo(cx - 26, cy)
        ..lineTo(cx - 8, cy - 14)
        ..lineTo(cx + 22, cy - 6)
        ..lineTo(cx + 12, cy + 12)
        ..lineTo(cx - 10, cy + 20)
        ..close();
      canvas.drawPath(path, _paint);
    }
  }

  // ---- world objects ------------------------------------------------------

  void _drawSpire(Canvas canvas, SpirePair p, double t) {
    final top = p.gapTopAt(t);
    final bottom = p.gapBottomAt(t);
    _spireBody(canvas, p, -10, top, true);
    _spireBody(canvas, p, bottom, WingyWorld.groundY, false);
    if (p.drifting) {
      // Shimmer on the tips marks a drifting gap.
      final a = 0.4 + 0.4 * sin(game.clock * 6);
      _paint.color = Color.fromARGB(
        (a * 255).round().clamp(0, 255),
        255,
        255,
        255,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.left - 3, top - 8, 62, 8),
          const Radius.circular(4),
        ),
        _paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.left - 3, bottom, 62, 8),
          const Radius.circular(4),
        ),
        _paint,
      );
    }
  }

  void _spireBody(
    Canvas canvas,
    SpirePair p,
    double y0,
    double y1,
    bool isTop,
  ) {
    final rect = Rect.fromLTRB(p.left, y0, p.right, y1);
    _paint.shader = Gradient.linear(
      Offset(rect.left, 0),
      Offset(rect.right, 0),
      const [Color(0xAA3CE0F0), Color(0xAAC050E0)],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      _paint,
    );
    _paint.shader = null;
    // One stylized facet highlight.
    _paint.color = const Color(0x40FFFFFF);
    final facet = Path()
      ..moveTo(rect.left + 8, rect.top)
      ..lineTo(rect.left + 20, rect.top)
      ..lineTo(rect.left + 14, rect.bottom)
      ..lineTo(rect.left + 6, rect.bottom)
      ..close();
    canvas.drawPath(facet, _paint);
    // Flat glowing tip at the gap side.
    final tipY = isTop ? y1 - 5 : y0;
    _paint.color = const Color(0xCCFFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.left, tipY, WingyWorld.spireWidth, 5),
        const Radius.circular(2),
      ),
      _paint,
    );
  }

  void _drawOrb(Canvas canvas, double x, double y) {
    final pulse = 1 + 0.1 * sin(game.clock * 5);
    final r = WingyWorld.orbRadius * pulse;
    _paint.shader = Gradient.radial(
      Offset(x, y),
      r * 2.2,
      const [Color(0xFFE9FFFF), Color(0x887FF7FF), Color(0x007FF7FF)],
      const [0.0, 0.45, 1.0],
    );
    canvas.drawCircle(Offset(x, y), r * 2.2, _paint);
    _paint.shader = null;
  }

  void _drawGround(Canvas canvas, double distance) {
    _paint.shader = Gradient.linear(
      const Offset(0, WingyWorld.groundY),
      const Offset(0, WingyWorld.height),
      const [Color(0xFF2B3B2F), Color(0xFF10151A)],
    );
    // The ground also fills any screen area below the 640 u world.
    canvas.drawRect(
      const Rect.fromLTWH(
        -200,
        WingyWorld.groundY,
        WingyWorld.width + 400,
        WingyWorld.height - WingyWorld.groundY + 600,
      ),
      _paint,
    );
    _paint.shader = null;
    // Tiny glowing mushrooms scrolling with the ground.
    const spacing = 90.0;
    final dx = distance % spacing;
    for (var i = -1; i < 5; i++) {
      final x = i * spacing - dx + 40;
      final h = 6 + ((i + (distance ~/ spacing)) % 3) * 3.0;
      _paint.color = const Color(0xFF3A4A52);
      canvas.drawRect(
        Rect.fromLTWH(x - 1, WingyWorld.groundY - h, 2, h),
        _paint,
      );
      _paint.color = const Color(0xCC8CF5C8);
      canvas.drawCircle(Offset(x, WingyWorld.groundY - h), 3.2, _paint);
    }
  }

  void _drawShards(Canvas canvas) {
    for (final s in _shards) {
      final a = (1 - s.age / 0.5).clamp(0.0, 1.0);
      final scale = 0.4 + 0.6 * a;
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.spin * s.age);
      canvas.scale(scale);
      _paint.color = Color.fromARGB((a * 200).round(), 120, 230, 245);
      canvas.drawPath(
        Path()
          ..moveTo(-12, 8)
          ..lineTo(0, -14)
          ..lineTo(12, 6)
          ..close(),
        _paint,
      );
      canvas.restore();
    }
  }

  void _drawMoth(Canvas canvas) {
    final run = game.run;
    var y = run.y;
    if (run.phase == RunPhase.ready) y += sin(game.clock * 3) * 6;
    var alpha = 1.0;
    if (run.isInvulnerable && (game.clock * 20).floor().isEven) alpha = 0.35;
    final tilt = (run.vy / 700).clamp(-0.6, 0.8);

    canvas.save();
    canvas.translate(WingyWorld.mothX, y);
    canvas.rotate(tilt);

    // Glow (bigger while dashing).
    final glowR = run.isDashing ? 46.0 : 30.0;
    _paint.shader = Gradient.radial(Offset.zero, glowR, [
      Color.fromARGB(
        (alpha * (run.isDashing ? 150 : 90)).round(),
        255,
        226,
        122,
      ),
      const Color(0x00FFE27A),
    ]);
    canvas.drawCircle(Offset.zero, glowR, _paint);
    _paint.shader = null;

    // Wings: 3 flap frames (up, mid, down), then a gentle idle flutter.
    final frame = _flapAge < 0.08 ? 0 : (_flapAge < 0.16 ? 1 : 2);
    final wingAngle = const [-0.9, -0.2, 0.45][frame];
    final flutter = frame == 2 ? sin(game.clock * 14) * 0.08 : 0.0;
    _paint.color = Color.fromARGB((alpha * 190).round(), 200, 190, 255);
    canvas.save();
    canvas.rotate(wingAngle + flutter);
    canvas.drawOval(const Rect.fromLTWH(-24, -18, 26, 16), _paint);
    canvas.drawOval(const Rect.fromLTWH(-20, 0, 20, 12), _paint);
    canvas.restore();
    _paint.color = Color.fromARGB((alpha * 110).round(), 170, 150, 240);
    canvas.drawOval(const Rect.fromLTWH(-20, -14, 22, 12), _paint);

    // Round body with a glowing abdomen.
    _paint.color = Color.fromARGB((alpha * 255).round(), 92, 64, 140);
    canvas.drawOval(const Rect.fromLTWH(-9, -9, 22, 18), _paint);
    _paint.color = Color.fromARGB((alpha * 255).round(), 255, 226, 122);
    canvas.drawCircle(const Offset(-6, 3), 5, _paint);
    // Eye and antenna.
    _paint.color = Color.fromARGB((alpha * 255).round(), 255, 255, 255);
    canvas.drawCircle(const Offset(8, -3), 2.4, _paint);
    _paint.color = const Color(0xFF14103A);
    canvas.drawCircle(const Offset(8.6, -3), 1.1, _paint);
    _paint
      ..color = Color.fromARGB((alpha * 255).round(), 230, 220, 255)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(10, -8), const Offset(16, -16), _paint);
    _paint.style = PaintingStyle.fill;
    canvas.restore();
  }

  void _drawTexts(Canvas canvas) {
    for (final t in _texts) {
      final a = (1 - t.age / 0.8).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: Color.fromARGB(
              (a * 255).round(),
              (t.color.r * 255).round(),
              (t.color.g * 255).round(),
              (t.color.b * 255).round(),
            ),
            fontSize: t.size,
            fontWeight: FontWeight.w800,
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(t.x, t.y));
    }
  }
}
