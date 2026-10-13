import 'package:calculator_app/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds a key sequence like '2+3*4=' into the engine.
/// Keys: 0-9, + - * /, =, C (AC), n (± sign toggle).
CalculatorEngine run(String keys, [CalculatorEngine? engine]) {
  final e = engine ?? CalculatorEngine();
  for (final k in keys.split('')) {
    switch (k) {
      case '+':
        e.inputOperator(Operator.add);
      case '-':
        e.inputOperator(Operator.subtract);
      case '*':
        e.inputOperator(Operator.multiply);
      case '/':
        e.inputOperator(Operator.divide);
      case '=':
        e.inputEquals();
      case 'C':
        e.allClear();
      case 'n':
        e.toggleSign();
      case ' ':
        break;
      default:
        e.inputDigit(int.parse(k));
    }
  }
  return e;
}

void main() {
  group('Core state contract', () {
    test('2 + 3: digit after operator starts the second operand', () {
      final e = run('2+3');
      expect(e.display, '3');
      expect(e.accumulator, 2);
      expect(e.pendingOperator, Operator.add);
      expect(e.expression, '2 +');
    });

    test('2 + 3 ×: next operator applies pending op, shows running total', () {
      final e = run('2+3*');
      expect(e.display, '5');
      expect(e.accumulator, 5);
      expect(e.pendingOperator, Operator.multiply);
      expect(e.awaitingOperand, isTrue);
    });

    test('2 + 3 × 4 = evaluates left to right to 20 (no precedence)', () {
      final e = run('2+3*4=');
      expect(e.display, '20');
      expect(e.pendingOperator, isNull);
      expect(e.justEvaluated, isTrue);
    });

    test('9 + × 2 =: second operator replaces the first', () {
      final e = run('9+');
      e.inputOperator(Operator.multiply);
      expect(e.display, '9');
      expect(e.pendingOperator, Operator.multiply);
      run('2=', e);
      expect(e.display, '18');
    });

    test('7 + =: equals without a new operand is ignored', () {
      final e = run('7+=');
      expect(e.display, '7');
      expect(e.pendingOperator, Operator.add);
      expect(e.awaitingOperand, isTrue);
      run('3=', e);
      expect(e.display, '10');
    });

    test('equals with nothing pending is ignored', () {
      expect(run('5=').display, '5');
      expect(run('5=').justEvaluated, isFalse);
    });

    test('digit after equals starts a new calculation', () {
      final e = run('2+3=');
      run('7', e);
      expect(e.display, '7');
      expect(e.accumulator, isNull);
      expect(e.pendingOperator, isNull);
      run('+1=', e);
      expect(e.display, '8');
    });

    test('operator after equals continues from the result', () {
      expect(run('2+3=*4=').display, '20');
    });

    test('all four operations chain left to right', () {
      expect(run('8-3*4/2+1=').display, '11'); // ((8-3)*4)/2+1
      expect(run('9-12=').display, '-3');
      expect(run('7/2=').display, '3.5');
      expect(run('10/3=').display, '3.333333333');
    });

    test('multi-digit entry and leading zero handling', () {
      expect(run('0012').display, '12');
      expect(run('123456789').display, '123456789');
      final e = run('1234567890');
      expect(e.display, '123456789'); // 10th digit rejected
      expect(e.message, contains('9 digits'));
    });
  });

  group('Feature: Clear / AC', () {
    test('AC clears operand, accumulator, pending operator and result phase',
        () {
      final e = run('2+3*');
      e.allClear();
      expect(e.display, '0');
      expect(e.accumulator, isNull);
      expect(e.pendingOperator, isNull);
      expect(e.awaitingOperand, isFalse);
      expect(e.justEvaluated, isFalse);
      expect(e.expression, '');
    });

    test('no stale accumulator after AC', () {
      // If AC left 5 behind, this would print 9 (5 + 4) or 20 (5 × 4).
      expect(run('2+3* C 4=').display, '4');
      expect(run('2+3* C 4+1=').display, '5');
    });

    test('AC after equals and after an error', () {
      expect(run('2+3= C').display, '0');
      final e = run('5/0=');
      e.allClear();
      expect(e.hasError, isFalse);
      expect(run('3+4=', e).display, '7');
    });
  });

  group('Feature: Error handling', () {
    test('division by zero shows a recoverable error', () {
      final e = run('5/0=');
      expect(e.hasError, isTrue);
      expect(e.display, 'Cannot divide by 0');
      expect(e.message, isNotNull);
    });

    test('division by zero mid-chain (5 / 0 +)', () {
      expect(run('5/0+').display, 'Cannot divide by 0');
    });

    test('operators are ignored during an error; a digit recovers', () {
      final e = run('5/0=+');
      expect(e.hasError, isTrue);
      run('6*2=', e);
      expect(e.hasError, isFalse);
      expect(e.display, '12');
    });

    test('incomplete input: equals after an operator gives a hint only', () {
      final e = run('7+=');
      expect(e.message, 'Enter a number first');
      expect(e.hasError, isFalse);
      run('1', e);
      expect(e.message, isNull);
    });

    test('overflow is reported instead of showing a wrong number', () {
      final e = run('999999999*999999999=');
      expect(e.display, 'Overflow');
      expect(e.hasError, isTrue);
    });
  });

  group('Feature: Positive / negative', () {
    test('toggles a typed operand and back', () {
      final e = run('12n');
      expect(e.display, '-12');
      run('n', e);
      expect(e.display, '12');
    });

    test('zero and empty input never become -0', () {
      expect(run('n').display, '0');
      expect(run('0n').display, '0');
    });

    test('negative operand in a calculation: 5 + 3± = 2', () {
      expect(run('5+3n=').display, '2');
    });

    test('digits keep the sign when typed after ±', () {
      expect(run('1n2').display, '-12');
    });

    test('while awaiting an operand, ± is ignored with a hint', () {
      final e = run('5+n');
      expect(e.display, '5');
      expect(e.message, 'Enter a number first');
    });

    test('toggling a result keeps it usable in the next operation', () {
      final e = run('2+3=n');
      expect(e.display, '-5');
      expect(run('*2=', e).display, '-10');
    });
  });

  test('format trims trailing zeros and normalizes -0', () {
    expect(CalculatorEngine.format(20), '20');
    expect(CalculatorEngine.format(-0.0), '0');
    expect(CalculatorEngine.format(0.5), '0.5');
  });
}
