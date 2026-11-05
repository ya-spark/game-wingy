import 'package:flutter/material.dart';

import '../core/parent_gate.dart';
import 'test_ids.dart';

/// "Ask a grown-up" dialog shown before any real-money purchase. Returns true when the
/// typed answer is right. A wrong answer shows a new question; three wrong answers in a
/// row close the dialog and lock purchases for [ParentGate.lockDuration].
Future<bool> showParentGate(BuildContext context, ParentGate gate) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentGateDialog(gate: gate),
  );
  return ok == true;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.gate});
  final ParentGate gate;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final TextEditingController _answer = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    final gate = widget.gate;
    if (gate.submit(_answer.text)) {
      Navigator.pop(context, true);
    } else if (gate.locked) {
      Navigator.pop(context, false);
    } else {
      setState(() {
        _wrong = true;
        _answer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = widget.gate;
    if (gate.locked) {
      return AlertDialog(
        key: TestIds.gateDialog,
        title: const Text('Ask a grown-up'),
        content: Text(
          'Purchases are paused. Try again in ${gate.lockLeft.inSeconds + 1} seconds.',
        ),
        actions: [
          TextButton(
            key: TestIds.gateCancel,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('OK'),
          ),
        ],
      );
    }
    return AlertDialog(
      key: TestIds.gateDialog,
      title: const Text('Ask a grown-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A grown-up needs to answer this to continue.'),
          const SizedBox(height: 12),
          Text(
            '${gate.question.text} = ?',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          if (_wrong)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Not quite. Here is a new one.'),
            ),
          TextField(
            key: TestIds.gateAnswer,
            controller: _answer,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: TestIds.gateCancel,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: TestIds.gateSubmit,
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
