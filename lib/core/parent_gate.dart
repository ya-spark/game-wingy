import 'dart:math';

import 'clock.dart';

/// One "ask a grown-up" question: a multiplication with factors 6 to 9.
class GateQuestion {
  const GateQuestion(this.a, this.b);
  final int a;
  final int b;
  int get answer => a * b;
  String get text => '$a x $b';
}

/// Logic of the parent gate shown before any real-money purchase: a wrong answer gives a
/// new question, [maxWrong] wrong answers in a row lock purchases for [lockDuration].
class ParentGate {
  ParentGate({Random? random, Clock? clock})
    : _random = random ?? Random(),
      _clock = clock ?? DateTime.now {
    question = _next(null);
  }

  static const int maxWrong = 3;
  static const Duration lockDuration = Duration(seconds: 60);

  final Random _random;
  final Clock _clock;
  late GateQuestion question;
  int _wrongInARow = 0;
  DateTime? _lockedUntil;

  bool get locked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _lockedUntil = null;
    _wrongInARow = 0;
    return false;
  }

  Duration get lockLeft =>
      locked ? _lockedUntil!.difference(_clock()) : Duration.zero;

  /// A new question that differs from [previous].
  GateQuestion _next(GateQuestion? previous) {
    while (true) {
      final q = GateQuestion(6 + _random.nextInt(4), 6 + _random.nextInt(4));
      if (previous == null || q.text != previous.text) return q;
    }
  }

  /// Checks a typed answer. Correct: true and the counter resets. Wrong: a new question,
  /// and the third wrong answer in a row starts the lock.
  bool submit(String typed) {
    if (locked) return false;
    final ok = int.tryParse(typed.trim()) == question.answer;
    if (ok) {
      _wrongInARow = 0;
    } else {
      _wrongInARow++;
      if (_wrongInARow >= maxWrong) _lockedUntil = _clock().add(lockDuration);
    }
    question = _next(question);
    return ok;
  }
}
