import 'package:flutter/material.dart';

/// Bright, kid-friendly palette used by the home and challenge screens.
abstract final class KidColors {
  static const skyTop = Color(0xFF7DD3FC);
  static const skyBottom = Color(0xFFFDE68A);
  static const sun = Color(0xFFFFB703);
  static const coral = Color(0xFFFF6B6B);
  static const grape = Color(0xFF8B5CF6);
  static const mint = Color(0xFF22C55E);
  static const ocean = Color(0xFF3B82F6);
  static const ink = Color(0xFF1E3A5F);
}

/// Full-screen sky gradient background.
class KidBackground extends StatelessWidget {
  const KidBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KidColors.skyTop, KidColors.skyBottom],
      ),
    ),
    child: child,
  );
}

/// Gently bobbing widget (code-drawn animation, no assets).
class Bobbing extends StatefulWidget {
  const Bobbing({super.key, required this.child, this.amplitude = 8});
  final Widget child;
  final double amplitude;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    builder: (context, child) => Transform.translate(
      offset: Offset(
        0,
        (Curves.easeInOut.transform(_c.value) - 0.5) * 2 * widget.amplitude,
      ),
      child: child,
    ),
    child: widget.child,
  );
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color ?? KidColors.ocean, width: 3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color ?? KidColors.ocean),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: KidColors.ink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Big, chunky, rounded gradient button with an icon and a press animation.
class MenuButton extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.primary = false,
    this.color,
    this.emoji,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;
  final Color? color;
  final String? emoji;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final base =
        widget.color ?? (widget.primary ? KidColors.mint : KidColors.ocean);
    final dark = HSLColor.fromColor(base).withLightness(0.32).toColor();
    final height = widget.primary ? 76.0 : 64.0;
    final button = AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HSLColor.fromColor(base).withLightness(0.62).toColor(),
                base,
              ],
            ),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: dark, offset: const Offset(0, 5)),
              const BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 9),
                blurRadius: 8,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.emoji != null)
                    Text(widget.emoji!, style: const TextStyle(fontSize: 26))
                  else
                    Icon(widget.icon, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.primary ? 30 : 22,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Colors.black38, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: 290,
      height: height,
      child: _BadgeDot(
        show: widget.badge,
        size: 16,
        backgroundColor: KidColors.coral,
        child: SizedBox.expand(child: button),
      ),
    );
  }
}

/// Small notification dot on a button's corner. Unlike [Badge] it never takes part
/// in hit testing, so the button underneath stays tappable.
class _BadgeDot extends StatelessWidget {
  const _BadgeDot({
    required this.show,
    required this.size,
    required this.backgroundColor,
    required this.child,
  });
  final bool show;
  final double size;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: child),
      if (show)
        Positioned(
          top: -2,
          right: 6,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
    ],
  );
}

/// White rounded card that groups a row on the colorful menu screens.
class KidPanel extends StatelessWidget {
  const KidPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Colorful full-page background with safe-area padding for the menu screens.
class KidPage extends StatelessWidget {
  const KidPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      KidBackground(child: SafeArea(child: child));
}
