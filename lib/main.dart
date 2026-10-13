import 'package:flutter/material.dart';

import 'calculator_engine.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalculatorEngine _engine = CalculatorEngine();

  /// Every button routes through here so the UI rebuilds from engine state.
  void _press(void Function(CalculatorEngine engine) action) {
    setState(() => action(_engine));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(flex: 2, child: _Display(engine: _engine)),
              const SizedBox(height: 12),
              Expanded(flex: 5, child: _buildKeypad()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    Widget digit(int d) => _CalcButton(
          label: '$d',
          kind: _ButtonKind.digit,
          onPressed: () => _press((e) => e.inputDigit(d)),
        );

    Widget op(Operator o) => _CalcButton(
          label: o.symbol,
          semanticLabel: o.spokenName,
          kind: _ButtonKind.operator,
          selected: _engine.awaitingOperand && _engine.pendingOperator == o,
          onPressed: () => _press((e) => e.inputOperator(o)),
        );

    return Column(
      children: [
        _row([
          _CalcButton(
            label: 'AC',
            semanticLabel: 'all clear',
            kind: _ButtonKind.function,
            flex: 2,
            onPressed: () => _press((e) => e.allClear()),
          ),
          _CalcButton(
            label: '±',
            semanticLabel: 'toggle sign',
            kind: _ButtonKind.function,
            onPressed: () => _press((e) => e.toggleSign()),
          ),
          op(Operator.divide),
        ]),
        _row([digit(7), digit(8), digit(9), op(Operator.multiply)]),
        _row([digit(4), digit(5), digit(6), op(Operator.subtract)]),
        _row([digit(1), digit(2), digit(3), op(Operator.add)]),
        _row([
          _CalcButton(
            label: '0',
            kind: _ButtonKind.digit,
            flex: 3,
            onPressed: () => _press((e) => e.inputDigit(0)),
          ),
          _CalcButton(
            label: '=',
            semanticLabel: 'equals',
            kind: _ButtonKind.operator,
            onPressed: () => _press((e) => e.inputEquals()),
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> buttons) =>
      Expanded(child: Row(children: buttons));
}

class _Display extends StatelessWidget {
  const _Display({required this.engine});

  final CalculatorEngine engine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message = engine.message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            engine.expression,
            key: const Key('expression'),
            style: textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          // FittedBox shrinks long numbers instead of overflowing on
          // narrow screens or with large system text.
          Semantics(
            liveRegion: true,
            label: engine.hasError ? 'Error: ${engine.display}' : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                engine.display,
                key: const Key('display'),
                maxLines: 1,
                style: textTheme.displayLarge?.copyWith(
                  color: engine.hasError ? scheme.error : scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: message == null
                ? null
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      key: const Key('message'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: scheme.tertiary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum _ButtonKind { digit, operator, function }

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.kind,
    required this.onPressed,
    this.semanticLabel,
    this.flex = 1,
    this.selected = false,
  });

  final String label;
  final String? semanticLabel;
  final _ButtonKind kind;
  final VoidCallback onPressed;
  final int flex;

  /// Highlights the pending operator while the next operand is expected.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (kind) {
      _ButtonKind.digit => (scheme.surfaceContainerHigh, scheme.onSurface),
      _ButtonKind.function => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ButtonKind.operator => selected
          ? (scheme.onPrimary, scheme.primary)
          : (scheme.primary, scheme.onPrimary),
    };

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Semantics(
          button: true,
          selected: selected,
          label: semanticLabel ?? label,
          excludeSemantics: true,
          onTap: onPressed,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onPressed,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
