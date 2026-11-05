import 'package:flutter/material.dart';

import '../core/profile/profile_store.dart';
import '../core/services.dart';
import 'test_ids.dart';

/// Opens the "Tip of the day" dialog: the tip, a "Don't show tips again" checkbox and Close.
/// Close alone hides it for now; with the box ticked it turns tips off everywhere (the same
/// saved profile value as the Settings "Show tips" switch).
Future<void> showTipDialog(BuildContext context, {required String text}) {
  final profile = ServicesScope.of(context).profile;
  return showDialog<void>(
    context: context,
    builder: (_) => TipDialog(text: text, profile: profile),
  );
}

class TipDialog extends StatefulWidget {
  const TipDialog({super.key, required this.text, required this.profile});

  final String text;
  final ProfileStore profile;

  @override
  State<TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<TipDialog> {
  bool _dontShow = false;

  Future<void> _close() async {
    if (_dontShow) await widget.profile.setTipsEnabled(false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: TestIds.tipHome,
      title: const Text('\u{1F4A1} Tip of the day'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: TestIds.tipDontShow,
            onTap: () => setState(() => _dontShow = !_dontShow),
            child: Row(
              children: [
                Checkbox(
                  value: _dontShow,
                  onChanged: (v) => setState(() => _dontShow = v ?? false),
                ),
                const Flexible(child: Text("Don't show tips again")),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: TestIds.tipClose,
          onPressed: _close,
          child: const Text('Close'),
        ),
      ],
    );
  }
}
