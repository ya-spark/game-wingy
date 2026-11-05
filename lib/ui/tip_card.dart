import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services.dart';
import 'test_ids.dart';

/// A small tip card with a "Don't show tips again" checkbox and a Close (X) button.
/// Close alone hides this tip for now; with the box ticked it turns tips off everywhere
/// (the same saved profile value as the Settings "Show tips" switch).
class TipCard extends StatefulWidget {
  const TipCard({
    super.key,
    required this.text,
    required this.onClose,
    this.title,
  });

  final String text;

  /// Optional heading, e.g. "Tip of the day".
  final String? title;

  /// Called after the card was closed (and tips turned off if the box was ticked).
  final VoidCallback onClose;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  bool _dontShow = false;

  Future<void> _close() async {
    if (_dontShow) {
      await ServicesScope.of(context).profile.setTipsEnabled(false);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: const Color(0xF2FFFFFF),
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 6),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Color(0xFF2B1B4D), fontSize: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null)
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            Text(
                              widget.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: TestIds.tipClose,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _close,
                    ),
                  ],
                ),
                InkWell(
                  key: TestIds.tipDontShow,
                  onTap: () => setState(() => _dontShow = !_dontShow),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: _dontShow,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) =>
                              setState(() => _dontShow = v ?? false),
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          "Don't show tips again",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tip in the pause dialog: fades in only after the game has been paused for [delay].
class PauseTip extends StatefulWidget {
  const PauseTip({super.key, required this.services});

  final Services services;
  static const delay = Duration(seconds: 3);

  @override
  State<PauseTip> createState() => _PauseTipState();
}

class _PauseTipState extends State<PauseTip> {
  Timer? _timer;
  bool _ready = false;
  bool _closed = false;
  late final String _tip = widget.services.tips.next();

  @override
  void initState() {
    super.initState();
    _timer = Timer(PauseTip.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services.profile,
      builder: (context, _) {
        final show = _ready && !_closed && widget.services.profile.tipsEnabled;
        return AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: show
              ? TipCard(
                  key: TestIds.tipPause,
                  text: _tip,
                  onClose: () => setState(() => _closed = true),
                )
              : const SizedBox(width: 280),
        );
      },
    );
  }
}
