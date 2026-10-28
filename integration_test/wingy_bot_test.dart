import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wingy/main.dart' as app;
import 'package:wingy/ui/test_ids.dart';

import '../test/helpers/wingy_bot.dart';
import '../test/rules/autopilot.dart';

/// Runs the real app on a device/emulator and flies the first spires with real taps on
/// `game.field`, reading state through the test IDs.
/// Run: `flutter test integration_test -d <device>` (optionally with
/// `--dart-define=WINGY_SEED=7` for a fixed gap sequence).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('autopilot bot flies through the first spires', (tester) async {
    app.main();
    // Wait for the home screen (bootstrap is async). No pumpAndSettle: ads/game animate forever.
    for (
      var i = 0;
      i < 100 && find.byKey(TestIds.homePlay).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
    expect(find.byKey(TestIds.homeBanner), findsOneWidget);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final bot = WingyBot(tester);
    await bot.waitForGame();
    expect(bot.scoreText(), '0');
    expect(find.byKey(TestIds.gameReady), findsOneWidget);

    await bot.tapField();
    for (var i = 0; i < 1500 && bot.run.isPlaying; i++) {
      if (autopilotWants(bot.run)) {
        await bot.tapField();
      } else {
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (bot.run.pairsPassed >= 3) break;
    }
    expect(bot.run.pairsPassed, greaterThanOrEqualTo(3));
    expect(bot.scoreText(), '${bot.run.score}');
    expect(int.parse(bot.scoreText()), greaterThanOrEqualTo(3));
    expect(find.byKey(TestIds.gameBanner), findsNothing);

    await tester.tap(find.byKey(TestIds.gameBack));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
