import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/app/taniin_app.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';

void main() {
  testWidgets('renders the Taniin game shell HUD', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const TaniinApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('COIN'), findsOneWidget);
    expect(find.text('TANI'), findsOneWidget);
    expect(find.text('CONNECT WALLET'), findsOneWidget);
  });

  test('persists planted plot state locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final farmState = FarmStateController();
    await farmState.loadSavedState();
    expect(farmState.performPlotAction(0), isTrue);
    await farmState.saveNow();

    final restored = FarmStateController();
    await restored.loadSavedState();

    expect(restored.plots[0].owned, isTrue);
    expect(restored.plots[0].status, PlotStatus.growing);
    expect(restored.plots[0].plantedAt, isNotNull);
    expect(restored.seeds[0].quantity, 5);

    farmState.dispose();
    restored.dispose();
  });

  test(
    'reverses swap assets and deposits TANI into Game Coin locally',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final farmState = FarmStateController();
      await farmState.loadSavedState();

      expect(farmState.swapFromAsset, SwapAsset.gameCoin);
      expect(farmState.swapToAsset, SwapAsset.taniSepolia);

      farmState.reverseSwapAssets();
      farmState.setSwapAmount(40);

      expect(farmState.swapFromAsset, SwapAsset.taniSepolia);
      expect(farmState.swapToAsset, SwapAsset.gameCoin);
      expect(farmState.swapSelectedAssets(), isTrue);
      expect(farmState.coins, 660);
      expect(farmState.tani, 46);

      farmState.dispose();
    },
  );
}
