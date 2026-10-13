# Calculator State Lab (CSC 4360)

A Flutter calculator that evaluates **left to right** with a visible running total
(no operator precedence: `2 + 3 × 4 = 20`).

Undergraduate features: **Clear / AC**, **Error handling**, **Positive / negative**.

## Structure
- `lib/calculator_engine.dart`: pure Dart state machine (accumulator, current input,
  pending operator, awaiting-operand and just-evaluated flags, error/message).
- `lib/main.dart`: UI. Every button calls one engine method inside `setState`.
- `test/calculator_engine_test.dart`: one test per state-contract transition plus feature tests.
- `test/calculator_widget_test.dart`: tap-through, small-screen, and screen-reader label tests.

## State contract
| Key sequence | Transition | Display |
|---|---|---|
| `2 + 3` | Store 2 and +; start the second operand at 3 | 3 |
| `×` | Apply 2 + 3, store 5, wait for next operand | 5 |
| `4 =` | Apply 5 × 4, finish | 20 |
| `9 + × 2 =` | Second operator replaces the first | 18 |
| `7 + =` | Equals ignored while awaiting an operand ("Enter a number first") | 7 |
| digit after `=` | Starts a new calculation | new digit |
| `AC` | Clears operand, accumulator, pending operator, result phase | 0 |
| `5 ÷ 0 =` | Error state; operators ignored; AC or a digit recovers | Cannot divide by 0 |
| `12 ±` | Flip sign; 0 never becomes -0; ignored while awaiting an operand | -12 |

## Run / build
```
flutter pub get
flutter test
flutter run
flutter build apk   # build/app/outputs/flutter-apk/app-release.apk
```
