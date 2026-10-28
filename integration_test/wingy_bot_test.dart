import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wingy/game/flame/wingy_game.dart';
import 'package:wingy/game/rules/wingy_run.dart';
import 'package:wingy/main.dart' as app;
import 'package:wingy/ui/test_ids.dart';

/// Runs the real app on a device/emulator and flaps with real taps on `game.field`.
/// Run: `flutter test integration_test -d <device> --dart-define=WINGY_SEED=1`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bot taps through the first seconds of a run', (tester) async {
    app.main();
    // Wait for the home screen (bootstrap is async). No pumpAndSettle: the game animates forever.
    for (
      var i = 0;
      i < 100 && find.byKey(TestIds.homePlay).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(TestIds.homePlay), findsOneWidget);

    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester
        .widget<GameWidget<WingyGame>>(find.byKey(TestIds.gameWidget))
        .game!;
    expect(game.run.phase, RunPhase.ready);

    await tester.tap(find.byKey(TestIds.gameReady));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (game.run.y > 330) {
        await tester.tap(find.byKey(TestIds.gameField));
      }
    }
    expect(game.run.phase, RunPhase.playing);
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameScore)).data,
      '${game.run.score}',
    );

    await tester.tap(find.byKey(TestIds.gameBack));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
