import 'package:flutter/material.dart';

/// Game-over overlay: a rounded dark card (solid surface at about 90 % opacity, thin light
/// border, soft shadow) so text and buttons never mix with the game behind it.
///
/// Top to bottom: [share] (top left) with the eye button (top right), title, [details],
/// [buttons] side by side, [refill], [primary] (Continue, large and gold, last).
/// While [hidden] the card fades out (0.2 s) and only the eye button stays; a tap anywhere
/// calls [onToggleView] to bring it back.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    super.key,
    required this.details,
    required this.buttons,
    required this.viewKey,
    required this.panelKey,
    required this.hidden,
    required this.onToggleView,
    this.share,
    this.refill,
    this.primary,
  });

  /// Score, best, medal... shown under the title.
  final List<Widget> details;

  /// Play again and Home, side by side.
  final List<GameOverButton> buttons;
  final GameOverButton? share;
  final GameOverButton? refill;

  /// Continue: large and gold, at the bottom.
  final GameOverButton? primary;
  final Key viewKey;
  final Key panelKey;
  final bool hidden;
  final VoidCallback onToggleView;

  static const surface = Color(0xE61B1233); // 90 % opaque deep indigo
  static const border = Color(0x66FFFFFF);
  static const fadeDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // A tap anywhere brings the panel back while it is hidden.
        if (hidden)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleView,
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Stack(
                  children: [
                    IgnorePointer(
                      ignoring: hidden,
                      child: AnimatedOpacity(
                        opacity: hidden ? 0 : 1,
                        duration: fadeDuration,
                        child: _card(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: hidden ? surface : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          key: viewKey,
                          tooltip: hidden ? 'Show results' : 'See the board',
                          color: Colors.white,
                          icon: Icon(
                            hidden ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: onToggleView,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      key: panelKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Share at the top left; the eye button overlays the top right.
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: share ?? const SizedBox.shrink(),
              ),
            ),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3A0), Color(0xFFFFB300)],
              ).createShader(r),
              child: const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: details),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: buttons[i]),
                ],
              ],
            ),
            if (refill != null) ...[const SizedBox(height: 10), refill!],
            if (primary != null) ...[const SizedBox(height: 14), primary!],
          ],
        ),
      ),
    );
  }
}

enum GameOverButtonKind { primary, secondary, ghost }

/// [large]: font 22, padding 28x16 (the focus action). [normal]: font 16, padding 20x11.
/// [small]: font 15, padding 18x9 (secondary actions).
enum GameOverButtonSize { large, normal, small }

/// Glossy pill button: gold for the main action, purple-pink for secondary, glass for ghost.
/// All label colours reach at least 4.5:1 against their fill.
class GameOverButton extends StatelessWidget {
  const GameOverButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.kind = GameOverButtonKind.secondary,
    this.size = GameOverButtonSize.normal,
  }) : assert(label != null || icon != null);

  /// Null for an icon-only button (then [semanticLabel] names it).
  final String? label;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameOverButtonKind kind;
  final GameOverButtonSize size;

  @override
  Widget build(BuildContext context) {
    final (colors, fg, border) = switch (kind) {
      GameOverButtonKind.primary => (
        const [Color(0xFFFFE259), Color(0xFFFF8F00)],
        const Color(0xFF3B1F00),
        const Color(0xFFFFF3A0),
      ),
      GameOverButtonKind.secondary => (
        const [Color(0xFF6D3BD0), Color(0xFFB83280)],
        Colors.white,
        const Color(0xFFFFD6F2),
      ),
      GameOverButtonKind.ghost => (
        const [Color(0x40FFFFFF), Color(0x26FFFFFF)],
        Colors.white,
        const Color(0xCCFFFFFF),
      ),
    };
    final (fontSize, padH, padV) = switch (size) {
      GameOverButtonSize.large => (22.0, 28.0, 16.0),
      GameOverButtonSize.normal => (16.0, 20.0, 11.0),
      GameOverButtonSize.small => (15.0, 18.0, 9.0),
    };
    final enabled = onPressed != null;
    return Semantics(
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      if (label != null) const SizedBox(width: 6),
                    ],
                    if (label != null)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label!,
                            style: TextStyle(
                              color: fg,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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
      ),
    );
  }
}
