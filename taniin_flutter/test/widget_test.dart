import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/app/taniin_app.dart';
import 'package:taniin_flutter/src/chain/auth_session.dart';
import 'package:taniin_flutter/src/chain/chain_client.dart';
import 'package:taniin_flutter/src/game/tmx_map.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';
import 'package:taniin_flutter/src/ui/game_hud.dart';
import 'package:taniin_flutter/src/ui/profile_panel.dart';
import 'package:taniin_flutter/src/ui/settings_panel.dart';
import 'package:taniin_flutter/src/ui/taniin_theme.dart';
import 'package:taniin_flutter/src/ui/hud/status_strip.dart';
import 'package:taniin_flutter/src/ui/wallet_panel.dart';

import 'support/fake_chain_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shows touch joystick on mobile web, but hides it on desktop web', () {
    expect(
      shouldShowTouchJoystickForPlatform(
        isWeb: true,
        platform: TargetPlatform.windows,
        viewportSize: const Size(1280, 720),
      ),
      isFalse,
    );
    expect(
      shouldShowTouchJoystickForPlatform(
        isWeb: true,
        platform: TargetPlatform.windows,
        viewportSize: const Size(960, 449),
      ),
      isFalse,
    );
    expect(
      shouldShowTouchJoystickForPlatform(
        isWeb: true,
        platform: TargetPlatform.windows,
        viewportSize: const Size(390, 844),
        coarsePointer: true,
      ),
      isTrue,
    );
    expect(
      shouldShowTouchJoystickForPlatform(
        isWeb: true,
        platform: TargetPlatform.android,
        viewportSize: const Size(932, 430),
      ),
      isTrue,
    );
    expect(
      shouldShowTouchJoystickForPlatform(
        isWeb: true,
        platform: TargetPlatform.android,
        viewportSize: const Size(1280, 720),
      ),
      isFalse,
    );
    expect(shouldShowTouchJoystickForPlatform(isWeb: false), isTrue);
  });

  test('keeps bridge centers open while blocking water at the sides', () {
    final leftBridgeGuards = bridgeWaterGuardRectsForTesting(
      bridgeTiles: <(int, int), int>{(0, 0): 1401, (1, 0): 1401},
      tileX: 0,
      tileY: 0,
      bridgeGid: 1401,
      left: 0,
      top: 0,
      size: 100,
    );
    final rightBridgeGuards = bridgeWaterGuardRectsForTesting(
      bridgeTiles: <(int, int), int>{(0, 0): 1401, (1, 0): 1401},
      tileX: 1,
      tileY: 0,
      bridgeGid: 1401,
      left: 100,
      top: 0,
      size: 100,
    );

    bool contains(List<Rect> rects, Offset point) {
      return rects.any((rect) => rect.contains(point));
    }

    expect(contains(leftBridgeGuards, const Offset(10, 50)), isTrue);
    expect(contains(leftBridgeGuards, const Offset(50, 50)), isFalse);
    expect(contains(rightBridgeGuards, const Offset(190, 50)), isTrue);
    expect(contains(rightBridgeGuards, const Offset(150, 50)), isFalse);
  });

  test('classifies river detail tiles as water blockers', () {
    expect(isWaterTileForTesting(844), isTrue);
    expect(isWaterTileForTesting(868), isTrue);
  });

  testWidgets('blocks the visible river while leaving bridge centers open', (
    WidgetTester tester,
  ) async {
    const tileSize = 128.0;
    final map = await TmxMap.loadCollisionDataForTesting('assets/game/map.tmx');
    final collisionRects = map.collisionRects(tileSize);

    Rect hitboxAtTile(int column, int row) {
      final x = (column + 0.5) * tileSize;
      final y = (row + 0.5) * tileSize;
      return Rect.fromLTRB(
        x - tileSize * 0.22,
        y - tileSize * 0.18,
        x + tileSize * 0.22,
        y + tileSize * 0.16,
      );
    }

    bool blocksPlayerAtTile(int column, int row) {
      final hitbox = hitboxAtTile(column, row);
      return collisionRects.any(hitbox.overlaps);
    }

    bool waterBlocksPlayerAtTile(int column, int row) {
      return map.blocksWaterHitbox(hitboxAtTile(column, row), tileSize);
    }

    expect(blocksPlayerAtTile(18, 9), isTrue);
    expect(blocksPlayerAtTile(19, 9), isTrue);
    expect(blocksPlayerAtTile(22, 9), isTrue);
    expect(blocksPlayerAtTile(23, 9), isFalse);
    expect(blocksPlayerAtTile(24, 9), isFalse);
    expect(blocksPlayerAtTile(25, 9), isTrue);
    expect(waterBlocksPlayerAtTile(18, 9), isTrue);
    expect(waterBlocksPlayerAtTile(19, 9), isTrue);
    expect(waterBlocksPlayerAtTile(23, 9), isFalse);
    expect(waterBlocksPlayerAtTile(24, 9), isFalse);
    expect(waterBlocksPlayerAtTile(25, 9), isTrue);
  });

  testWidgets('keeps wallet login hidden while loading is active', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const TaniinApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Login Wallet'), findsNothing);
    expect(find.text('COIN'), findsNothing);
  });

  testWidgets('keeps the game HUD hidden while loading is active', (
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

    expect(find.text('COIN'), findsNothing);
    expect(find.text('Login Wallet'), findsNothing);
  });

  testWidgets('guest wallet panel offers Privy login without address input', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController();
    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://example.com'));
    addTearDown(farmState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: WalletPanel(farmState: farmState, onClose: () {}),
        ),
      ),
    );

    expect(find.text('Masuk dengan Privy'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Keluar'), findsNothing);
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

    await tester.tap(find.text('Tentang'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rahmat Eka Satria'), findsWidgets);
    expect(find.text('rhmatzeka'), findsOneWidget);
  });

  testWidgets('signed-in wallet panel shows the account and logs out', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController(chainClientFactory: FakeChainClient.new);
    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://example.com'));
    addTearDown(farmState.dispose);
    await tester.runAsync(() => farmState.applyAuthSession(fakeSession()));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: WalletPanel(farmState: farmState, onClose: () {}),
        ),
      ),
    );

    expect(find.text(shortAddress(fakeWallet)), findsWidgets);
    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(farmState.isLoggedIn, isFalse);
    expect(farmState.walletAddress, isEmpty);
  });

  testWidgets('status strip labels every service', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController();
    addTearDown(farmState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: StatusStrip(
            farmState: farmState,
            multiplayerOnline: false,
            aiOnline: false,
          ),
        ),
      ),
    );

    // Collapsed: one summary that still tells screen readers every service.
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Multiplayer: offline')), findsOneWidget);
    expect(find.text('Sepolia'), findsNothing);

    await tester.tap(find.textContaining('offline'));
    await tester.pump();
    for (final label in <String>['Akun', 'Sepolia', 'Server', 'Multiplayer', 'AI']) {
      expect(find.text(label), findsOneWidget);
    }
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

  test('unlocks and persists progression cosmetics', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = FarmStateController();
    await state.loadSavedState();

    for (var i = 0; i < 3; i++) {
      state.seeds[0] = state.seeds[0].copyWith(quantity: 10);
      final plot = state.plots[0]
        ..status = PlotStatus.empty
        ..plantedAt = null;
      expect(state.performPlotAction(0), isTrue);
      plot
        ..status = PlotStatus.empty
        ..plantedAt = null;
    }

    expect(state.playerXp, 30);
    expect(state.dailyQuests.first.completed, isTrue);
    expect(state.unlockedAchievements, contains('Langkah Pertama'));

    state.playerXp = 100;
    state.setPlayerName('  Petani   Nusantara  ');
    state.equipCosmetic('farmer_classic');
    state.performPlotAction(0);
    expect(state.ownedCosmeticIds, contains('farmer_nusantara'));
    expect(state.equipCosmetic('farmer_nusantara'), isTrue);
    await state.saveNow();

    final restored = FarmStateController();
    await restored.loadSavedState();
    expect(restored.playerName, 'Petani Nusantara');
    expect(restored.playerLevel, 2);
    expect(restored.equippedCosmeticId, 'farmer_nusantara');
    expect(restored.ownedCosmeticIds, contains('farmer_nusantara'));

    state.dispose();
    restored.dispose();
  });

  testWidgets('profile panel shows quests and wardrobe', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = FarmStateController();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: ProfilePanel(farmState: state, onClose: () {}),
        ),
      ),
    );

    expect(find.textContaining('Profil Petani'), findsOneWidget);
    expect(find.text('Quest harian'), findsOneWidget);
    expect(find.text('Baju petani'), findsOneWidget);
    expect(find.text('Petani Klasik'), findsOneWidget);
    expect(find.text('Petani Nusantara'), findsOneWidget);
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
      expect(await farmState.swapSelectedAssets(), isTrue);
      expect(farmState.coins, 660);
      expect(farmState.tani, 46);

      farmState.dispose();
    },
  );

  test('ETH funding callback submits the payment hash to the server', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late FakeChainClient fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) => fakeClient = FakeChainClient(config),
    );
    addTearDown(farmState.dispose);
    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    await farmState.applyAuthSession(fakeSession());
    fakeClient.serverState = <String, Object?>{'coins': 820};

    await farmState.handleFundCallback(
      const FundCallback(txHash: fakeTxHash, amount: 200),
    );

    expect(fakeClient.actions.single.type, 'SWAP_ETH_COIN');
    expect(fakeClient.actions.single.paymentTxHash, fakeTxHash);
    expect(fakeClient.actions.single.amount, 200);
    expect(farmState.coins, 820);
    expect(farmState.history.first.txHash, fakeTxHash);
  });

  test('keeps ETH payout pending until Sepolia receipt confirms', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late FakeChainClient fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) => fakeClient = FakeChainClient(config)
        ..receiptState = ChainReceiptState.pending(
          'Transaksi fake belum confirmed.',
        ),
    );
    addTearDown(farmState.dispose);

    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    await farmState.applyAuthSession(fakeSession());
    await pumpEventQueue();
    fakeClient.serverState = <String, Object?>{'coins': 600};
    farmState
      ..walletNativeBalance = '0.001'
      ..walletNativeWei = '1000000000000000'
      ..ethWeiPerCoin = '10000000000'
      ..maxEthPayoutWei = '1000000000000';

    farmState.setSwapFromAsset(SwapAsset.gameCoin);
    farmState.setSwapToAsset(SwapAsset.ethSepolia);
    farmState.setSwapAmount(100);

    expect(await farmState.swapSelectedAssets(), isTrue);
    await pumpEventQueue();

    expect(fakeClient.actions.single.type, 'SWAP_COIN_ETH');
    expect(farmState.coins, 600);
    expect(farmState.history.first.txHash, fakeTxHash);
    expect(farmState.history.first.status, 'menunggu konfirmasi');
    expect(farmState.chainStatus, contains('belum confirmed'));
  });

  test('confirms ETH payout after wallet Sepolia balance increases', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late FakeChainClient fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) => fakeClient = FakeChainClient(config)
        ..nativeEth = '0.011'
        ..nativeWei = '11000000000000000'
        ..ethWeiPerCoin = '100000000000000'
        ..maxEthPayoutWei = '100000000000000000',
    );
    addTearDown(farmState.dispose);

    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    await farmState.applyAuthSession(fakeSession());
    await pumpEventQueue();
    fakeClient.serverState = <String, Object?>{'coins': 520};
    final loadsBefore = fakeClient.walletLoads;
    farmState
      ..walletNativeBalance = '0.001'
      ..walletNativeWei = '1000000000000000'
      ..ethWeiPerCoin = '100000000000000'
      ..maxEthPayoutWei = '100000000000000000';

    farmState.setSwapFromAsset(SwapAsset.gameCoin);
    farmState.setSwapToAsset(SwapAsset.ethSepolia);
    farmState.setSwapAmount(100);

    expect(
      farmState.swapCardAmountLabel(SwapAsset.ethSepolia, 100, to: true),
      '+0.01 ETH',
    );
    expect(await farmState.swapSelectedAssets(), isTrue);
    await pumpEventQueue();

    expect(fakeClient.actions.single.type, 'SWAP_COIN_ETH');
    expect(fakeClient.walletLoads, greaterThan(loadsBefore));
    expect(farmState.walletNativeBalance, '0.011');
    expect(farmState.history.first.status, 'on-chain');
    expect(farmState.chainStatus, contains('Payout +0.01 ETH confirmed'));
  });
}
