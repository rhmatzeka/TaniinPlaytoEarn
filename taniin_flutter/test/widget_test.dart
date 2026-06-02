import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/app/taniin_app.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';
import 'package:taniin_flutter/src/ui/settings_panel.dart';
import 'package:taniin_flutter/src/ui/taniin_theme.dart';
import 'package:taniin_flutter/src/ui/wallet_panel.dart';

void main() {
  testWidgets('requires wallet login before showing the game HUD', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const TaniinApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Login Wallet'), findsOneWidget);
    expect(
      find.text('Connect wallet dulu untuk mulai bermain'),
      findsOneWidget,
    );
    expect(find.text('COIN'), findsNothing);
  });

  testWidgets('renders the game HUD when a wallet session is saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'taniin.farmState.v1': jsonEncode(<String, Object>{
        'version': 1,
        'walletConnected': true,
        'walletAddress': '0x0000000000000000000000000000000000000001',
      }),
    });

    await tester.pumpWidget(const TaniinApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Login Wallet'), findsNothing);
    expect(find.text('COIN'), findsOneWidget);
    expect(find.text('TANI'), findsOneWidget);
  });

  testWidgets('settings about tab shows creator and github link', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController();
    addTearDown(farmState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: SettingsPanel(farmState: farmState, onClose: () {}),
        ),
      ),
    );

    await tester.tap(find.text('ABOUT'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rahmat Eka Satria'), findsWidgets);
    expect(find.text('rhmatzeka'), findsOneWidget);
  });

  testWidgets('wallet panel logout disconnects the active wallet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController()
      ..walletConnected = true
      ..walletAddress = '0x0000000000000000000000000000000000000001';
    addTearDown(farmState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: WalletPanel(farmState: farmState, onClose: () {}),
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pump();

    expect(farmState.walletConnected, isFalse);
    expect(farmState.walletAddress, isEmpty);
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
