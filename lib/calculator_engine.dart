/// Left-to-right running-total calculator state machine.
///
/// The engine owns every piece of calculator state. The UI only calls the
/// input methods below and renders [display], [expression], and [message].
/// There is no operator precedence: 2 + 3 × 4 = (2 + 3) × 4 = 20.
library;

enum Operator { add, subtract, multiply, divide }

extension OperatorSymbol on Operator {
  String get symbol => switch (this) {
        Operator.add => '+',
        Operator.subtract => '−',
        Operator.multiply => '×',
        Operator.divide => '÷',
      };

  /// Spoken name used for screen reader labels.
  String get spokenName => switch (this) {
        Operator.add => 'plus',
        Operator.subtract => 'minus',
        Operator.multiply => 'times',
        Operator.divide => 'divided by',
      };
}

class CalculatorEngine {
  /// Longest operand a user can type (digits only, sign excluded).
  static const int maxDigits = 9;

  /// Results larger than this are reported as overflow instead of being
  /// shown with lost precision.
  static const double maxMagnitude = 1e15;

  /// Running total; null until the first operator is chosen.
  double? _accumulator;

  /// Text of the operand being typed, or of the latest result.
  String _currentInput = '0';

  /// Operation waiting for its right-hand operand.
  Operator? _pendingOperator;

  /// True right after an operator: the next digit starts a new operand.
  bool _awaitingOperand = false;

  /// True right after equals: the next digit starts a fresh calculation.
  bool _justEvaluated = false;

  /// Set when a calculation fails (division by zero, overflow).
  String? _error;

  /// Short, non-blocking hint such as "Enter a number first".
  String? _message;

  // ---- Read-only view of state -------------------------------------------

  double? get accumulator => _accumulator;
  Operator? get pendingOperator => _pendingOperator;
  bool get awaitingOperand => _awaitingOperand;
  bool get justEvaluated => _justEvaluated;
  bool get hasError => _error != null;
  String? get message => _message;

  /// Main display: the error text, or the current operand / running total.
  String get display => _error ?? _currentInput;

  /// Secondary line showing the pending part of the calculation, e.g. "5 ×".
  String get expression {
    if (_error != null || _pendingOperator == null || _accumulator == null) {
      return '';
    }
    return '${format(_accumulator!)} ${_pendingOperator!.symbol}';
  }

  // ---- Inputs ------------------------------------------------------------

  void inputDigit(int digit) {
    assert(digit >= 0 && digit <= 9);
    _message = null;

    // A digit after an error or after equals starts a fresh calculation.
    if (_error != null || _justEvaluated) {
      _resetState();
    }

    if (_awaitingOperand) {
      _currentInput = '$digit';
      _awaitingOperand = false;
      return;
    }

    final negative = _currentInput.startsWith('-');
    final digits = negative ? _currentInput.substring(1) : _currentInput;
    if (digits.length >= maxDigits) {
      _message = 'Maximum $maxDigits digits';
      return;
    }
    final next = digits == '0' ? '$digit' : '$digits$digit';
    _currentInput = negative ? '-$next' : next;
  }

  void inputOperator(Operator op) {
    _message = null;
    if (_error != null) {
      _message = 'Press AC or a digit to start over';
      return;
    }

    // Operator twice in a row: replace the pending one.
    if (_awaitingOperand && _pendingOperator != null) {
      _pendingOperator = op;
      return;
    }

    final operand = double.parse(_currentInput);
    if (_pendingOperator != null && _accumulator != null) {
      // Apply the pending operation first and show the running total.
      final result = _apply(_accumulator!, _pendingOperator!, operand);
      if (result == null) return;
      _accumulator = result;
      _currentInput = format(result);
    } else {
      _accumulator = operand;
    }

    _pendingOperator = op;
    _awaitingOperand = true;
    _justEvaluated = false;
  }

  void inputEquals() {
    _message = null;
    if (_error != null) return;

    // Nothing pending, or no new operand yet: equals is ignored.
    if (_pendingOperator == null || _accumulator == null) return;
    if (_awaitingOperand) {
      _message = 'Enter a number first';
      return;
    }

    final result =
        _apply(_accumulator!, _pendingOperator!, double.parse(_currentInput));
    if (result == null) return;

    _accumulator = result;
    _currentInput = format(result);
    _pendingOperator = null;
    _awaitingOperand = false;
    _justEvaluated = true;
  }

  /// AC: clears the display, accumulator, pending operator, and result phase.
  void allClear() {
    _resetState();
    _message = null;
  }

  /// ± : flips the sign of the current operand or result.
  ///
  /// Zero stays 0 (no "-0"). While waiting for an operand there is no input
  /// to flip, so the press is ignored with a hint.
  void toggleSign() {
    _message = null;
    if (_error != null) return;
    if (_awaitingOperand) {
      _message = 'Enter a number first';
      return;
    }
    if (double.parse(_currentInput) == 0) {
      _currentInput = '0';
      return;
    }
    _currentInput = _currentInput.startsWith('-')
        ? _currentInput.substring(1)
        : '-$_currentInput';
  }

  // ---- Helpers -----------------------------------------------------------

  /// Returns the result, or null after putting the engine in an error state.
  double? _apply(double left, Operator op, double right) {
    if (op == Operator.divide && right == 0) {
      _fail('Cannot divide by 0');
      return null;
    }
    final result = switch (op) {
      Operator.add => left + right,
      Operator.subtract => left - right,
      Operator.multiply => left * right,
      Operator.divide => left / right,
    };
    if (!result.isFinite || result.abs() >= maxMagnitude) {
      _fail('Overflow');
      return null;
    }
    return result;
  }

  void _fail(String text) {
    _resetState();
    _error = text;
    _message = 'Press AC or a digit to start over';
  }

  void _resetState() {
    _accumulator = null;
    _currentInput = '0';
    _pendingOperator = null;
    _awaitingOperand = false;
    _justEvaluated = false;
    _error = null;
  }

  /// Formats a number without a trailing ".0" and with at most 10
  /// significant digits for fractional results (e.g. 10 ÷ 3).
  static String format(double value) {
    if (value == 0) return '0'; // also normalizes -0.0
    if (value == value.truncateToDouble()) return value.toInt().toString();
    var text = value.toStringAsPrecision(10);
    if (text.contains('e')) return text;
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }
}
