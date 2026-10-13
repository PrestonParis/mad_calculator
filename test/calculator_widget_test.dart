import 'package:calculator_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapKeys(WidgetTester tester, List<String> keys) async {
  for (final k in keys) {
    await tester.tap(find.text(k).last);
    await tester.pump();
  }
}

String displayText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('display'))).data!;

void main() {
  testWidgets('2 + 3 × 4 = shows running total 5 then 20', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    expect(displayText(tester), '0');

    await tapKeys(tester, ['2', '+', '3', '×']);
    expect(displayText(tester), '5');
    expect(find.text('5 ×'), findsOneWidget);

    await tapKeys(tester, ['4', '=']);
    expect(displayText(tester), '20');
  });

  testWidgets('division by zero shows error; AC recovers', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['8', '÷', '0', '=']);
    expect(displayText(tester), 'Cannot divide by 0');

    await tapKeys(tester, ['AC']);
    expect(displayText(tester), '0');
  });

  testWidgets('sign toggle', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['5', '±']);
    expect(displayText(tester), '-5');
  });

  testWidgets('fits a small phone screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CalculatorApp());
    await tapKeys(tester, ['9', '9', '9', '9', '9', '9', '9', '9', '9']);
    expect(displayText(tester), '999999999');
    expect(tester.takeException(), isNull);
  });

  testWidgets('buttons have screen reader labels', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const CalculatorApp());
    for (final label in ['plus', 'minus', 'times', 'divided by', 'equals',
        'all clear', 'toggle sign']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });
}
