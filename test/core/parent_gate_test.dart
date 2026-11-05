import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingy/core/parent_gate.dart';

void main() {
  late DateTime now;
  late ParentGate gate;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    gate = ParentGate(random: Random(3), clock: () => now);
  });

  test('questions are multiplications with factors 6 to 9', () {
    for (var i = 0; i < 50; i++) {
      final q = gate.question;
      expect(q.a, inInclusiveRange(6, 9));
      expect(q.b, inInclusiveRange(6, 9));
      expect(q.answer, q.a * q.b);
      expect(q.text, '${q.a} x ${q.b}');
      gate.submit('0');
      now = now.add(const Duration(minutes: 5)); // never reach the lock
    }
  });

  test('a correct answer passes', () {
    expect(gate.submit('${gate.question.answer}'), isTrue);
    expect(gate.locked, isFalse);
  });

  test('a wrong answer gives a new question', () {
    final before = gate.question.text;
    expect(gate.submit('1'), isFalse);
    expect(gate.question.text, isNot(before));
    expect(gate.locked, isFalse);
  });

  test('three wrong answers in a row lock for 60 s', () {
    gate.submit('1');
    gate.submit('2');
    expect(gate.locked, isFalse);
    gate.submit('3');
    expect(gate.locked, isTrue);
    // Even the right answer is refused while locked.
    expect(gate.submit('${gate.question.answer}'), isFalse);
    now = now.add(const Duration(seconds: 59));
    expect(gate.locked, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(gate.locked, isFalse);
    expect(gate.submit('${gate.question.answer}'), isTrue);
  });

  test('a correct answer resets the wrong counter', () {
    gate.submit('1');
    gate.submit('2');
    gate.submit('${gate.question.answer}');
    gate.submit('3');
    gate.submit('4');
    expect(gate.locked, isFalse);
  });
}
