import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/app/taniin_app.dart';
import 'package:taniin_flutter/src/chain/chain_client.dart';
import 'package:taniin_flutter/src/game/tmx_map.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';
import 'package:taniin_flutter/src/ui/game_hud.dart';
import 'package:taniin_flutter/src/ui/profile_panel.dart';
import 'package:taniin_flutter/src/ui/settings_panel.dart';
import 'package:taniin_flutter/src/ui/taniin_theme.dart';
import 'package:taniin_flutter/src/ui/wallet_panel.dart';

const String _validTxHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

class _FakeChainClient extends ChainClient {
  _FakeChainClient(super.config);

  final List<ChainAction> actions = <ChainAction>[];
  ChainReceiptState receiptState = ChainReceiptState.ok('Confirmed fake.');
  String nativeEth = '0.001';
  String nativeWei = '1000000000000000';
  String ethWeiPerCoin = '10000000000';
  String maxEthPayoutWei = '1000000000000';
  int walletLoads = 0;

  @override
  Future<ChainResult> submitGameAction(
    String walletAddress,
    ChainAction action,
  ) async {
    actions.add(action);
    return ChainResult.ok('Transaksi fake terkirim.', txHash: _validTxHash);
  }

  @override
  Future<ChainReceiptState> waitForTransaction(String txHash) async {
    return receiptState;
  }

  @override
  Future<ChainWalletState> loadWalletState(String walletAddress) async {
    walletLoads += 1;
    return ChainWalletState.ok(
      message: 'Wallet fake tersync Sepolia.',
      coinBalance: 0,
      coinBalanceAvailable: false,
      nativeEth: nativeEth,
      nativeWei: nativeWei,
      signerAddress: '0x0000000000000000000000000000000000000002',
      ethWeiPerCoin: ethWeiPerCoin,
      maxEthPayoutWei: maxEthPayoutWei,
    );
  }
}

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

  testWidgets('renders wallet login panel copy', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController();
    farmState.configureChain(
      const ChainConfig(
        gameApiUrl: 'https://example.com',
        defaultWalletAddress: '0x0000000000000000000000000000000000000001',
      ),
    );
    addTearDown(farmState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaniinTheme(),
        home: Scaffold(
          body: WalletPanel(
            farmState: farmState,
            onClose: () {},
            showCloseButton: false,
            prominent: true,
            showFacts: false,
            title: 'Login Wallet',
            subtitle: 'Connect wallet dulu untuk mulai bermain',
          ),
        ),
      ),
    );

    expect(find.text('Login Wallet'), findsOneWidget);
    expect(
      find.text('Connect wallet dulu untuk mulai bermain'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Connect wallet untuk mulai bermain dan sync transaksi Sepolia.',
      ),
      findsOneWidget,
    );
    expect(find.text('Wallet: '), findsNothing);
    expect(find.text('API: '), findsNothing);
    expect(farmState.chainStatus, isNot(contains('backend/testing')));
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

    expect(find.textContaining('PROFIL PETANI'), findsOneWidget);
    expect(find.text('QUEST HARIAN'), findsOneWidget);
    expect(find.text('WARDROBE'), findsOneWidget);
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
      expect(farmState.swapSelectedAssets(), isTrue);
      expect(farmState.coins, 660);
      expect(farmState.tani, 46);

      farmState.dispose();
    },
  );

  test('adds Game Coin after successful ETH Sepolia funding tx', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _FakeChainClient? fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) {
        fakeClient = _FakeChainClient(config);
        return fakeClient!;
      },
    );
    addTearDown(farmState.dispose);

    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    farmState
      ..walletConnected = true
      ..walletAddress = '0x0000000000000000000000000000000000000001'
      ..walletNativeBalance = '0.001'
      ..walletNativeWei = '1000000000000000'
      ..ethWeiPerCoin = '10000000000'
      ..maxEthPayoutWei = '1000000000000';

    farmState.setSwapFromAsset(SwapAsset.ethSepolia);
    farmState.setSwapToAsset(SwapAsset.gameCoin);
    farmState.setSwapAmount(25);

    expect(farmState.ethCoinCapacity, 100);
    expect(farmState.swapSelectedAssets(), isTrue);
    expect(farmState.coins, 620);

    await Future<void>.delayed(Duration.zero);

    expect(fakeClient?.actions.single.type, 'SWAP_ETH_COIN');
    expect(farmState.coins, 645);
    expect(farmState.history.first.txHash, _validTxHash);
    expect(farmState.history.first.status, 'on-chain');
  });

  test('keeps ETH payout pending until Sepolia receipt confirms', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _FakeChainClient? fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) {
        fakeClient = _FakeChainClient(config)
          ..receiptState = ChainReceiptState.pending(
            'Transaksi fake belum confirmed.',
          );
        return fakeClient!;
      },
    );
    addTearDown(farmState.dispose);

    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    farmState
      ..walletConnected = true
      ..walletAddress = '0x0000000000000000000000000000000000000001'
      ..walletNativeBalance = '0.001'
      ..walletNativeWei = '1000000000000000'
      ..ethWeiPerCoin = '10000000000'
      ..maxEthPayoutWei = '1000000000000';

    farmState.setSwapFromAsset(SwapAsset.gameCoin);
    farmState.setSwapToAsset(SwapAsset.ethSepolia);
    farmState.setSwapAmount(20);

    expect(farmState.swapSelectedAssets(), isTrue);
    expect(farmState.coins, 600);

    await Future<void>.delayed(Duration.zero);

    expect(fakeClient?.actions.single.type, 'SWAP_COIN_ETH');
    expect(farmState.coins, 600);
    expect(farmState.history.first.txHash, _validTxHash);
    expect(farmState.history.first.status, 'menunggu konfirmasi');
    expect(farmState.chainStatus, contains('belum confirmed'));
  });

  test('confirms ETH payout after wallet Sepolia balance increases', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _FakeChainClient? fakeClient;
    final farmState = FarmStateController(
      chainClientFactory: (config) {
        fakeClient = _FakeChainClient(config)
          ..nativeEth = '0.003'
          ..nativeWei = '3000000000000000'
          ..ethWeiPerCoin = '100000000000000'
          ..maxEthPayoutWei = '100000000000000000';
        return fakeClient!;
      },
    );
    addTearDown(farmState.dispose);

    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
    farmState
      ..walletConnected = true
      ..walletAddress = '0x0000000000000000000000000000000000000001'
      ..walletNativeBalance = '0.001'
      ..walletNativeWei = '1000000000000000'
      ..ethWeiPerCoin = '100000000000000'
      ..maxEthPayoutWei = '100000000000000000';

    farmState.setSwapFromAsset(SwapAsset.gameCoin);
    farmState.setSwapToAsset(SwapAsset.ethSepolia);
    farmState.setSwapAmount(20);

    expect(
      farmState.swapCardAmountLabel(SwapAsset.ethSepolia, 20, to: true),
      '+0.002 ETH',
    );
    expect(farmState.swapSelectedAssets(), isTrue);
    expect(farmState.coins, 600);

    await pumpEventQueue();

    expect(fakeClient?.actions.single.type, 'SWAP_COIN_ETH');
    expect(fakeClient?.walletLoads, 1);
    expect(farmState.walletNativeBalance, '0.003');
    expect(farmState.history.first.txHash, _validTxHash);
    expect(farmState.history.first.status, 'on-chain');
    expect(farmState.chainStatus, contains('Payout +0.002 ETH confirmed'));
  });
}
