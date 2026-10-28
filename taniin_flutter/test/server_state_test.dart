import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/chain/auth_session.dart';
import 'package:taniin_flutter/src/chain/chain_client.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';

import 'support/fake_chain_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChainClient fake;
  late FarmStateController farmState;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    farmState = FarmStateController(
      chainClientFactory: (config) => fake = FakeChainClient(config),
    );
    await farmState.loadSavedState();
    farmState.configureChain(const ChainConfig(gameApiUrl: 'https://api.test'));
  });

  tearDown(() => farmState.dispose());

  test('guest actions stay local and never call the server', () async {
    expect(farmState.isLoggedIn, isFalse);
    expect(farmState.performPlotAction(0), isTrue);
    await pumpEventQueue();
    expect(fake.actions, isEmpty);
    expect(farmState.history.first.status, 'lokal tersimpan');
  });

  test('first login imports guest progress once and applies server state', () async {
    farmState.coins = 300;
    fake.serverState = <String, Object?>{
      'coins': 300,
      'seedQuantities': <int>[6, 0, 0, 0],
    };
    await farmState.applyAuthSession(fakeSession());

    expect(farmState.isLoggedIn, isTrue);
    expect(farmState.walletAddress, fakeWallet);
    expect(fake.imports, hasLength(1));
    expect(fake.imports.single['coins'], 300);

    await farmState.logout();
    await farmState.applyAuthSession(fakeSession());
    expect(fake.imports, hasLength(1));
  });

  test('server state from an action replaces the optimistic local state', () async {
    await farmState.applyAuthSession(fakeSession());
    fake.serverState = <String, Object?>{'coins': 999};

    expect(farmState.performPlotAction(0), isTrue);
    await pumpEventQueue();

    expect(fake.actions.single.type, 'PLANT');
    expect(fake.actions.single.seedIndex, 0);
    expect(fake.idempotencyKeys.single, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(farmState.coins, 999);
  });

  test('an expired session logs the player out with a clear message', () async {
    await farmState.applyAuthSession(fakeSession());
    fake.actionResult = (_) => ChainResult.unauthorized('Sesi habis, masuk lagi.');

    farmState.performPlotAction(0);
    await pumpEventQueue();

    expect(farmState.isLoggedIn, isFalse);
    expect(farmState.statusMessage, contains('Sesi habis'));
  });

  test('a rejected action resyncs the server state', () async {
    await farmState.applyAuthSession(fakeSession());
    fake.serverState = <String, Object?>{'coins': 620, 'seedQuantities': <int>[6, 0, 0, 0]};
    fake.actionResult = (_) => ChainResult.error('Tanaman belum siap panen.');

    farmState.performPlotAction(0);
    await pumpEventQueue();

    expect(farmState.seeds.first.quantity, 6);
    expect(farmState.history.first.status, 'gagal');
  });

  test('logout returns to the saved guest farm', () async {
    farmState.coins = 123;
    await farmState.saveNow();
    fake.serverState = <String, Object?>{'coins': 5000};
    await farmState.applyAuthSession(fakeSession());
    expect(farmState.coins, 5000);

    await farmState.logout();

    expect(fake.logouts, 1);
    expect(farmState.isLoggedIn, isFalse);
    expect(farmState.coins, 123);
  });

  test('the app redeems a one-time code with its stored verifier', () async {
    final url = await farmState.prepareLoginUrl(forApp: true);
    final challenge = Uri.parse(url).queryParameters['challenge'];
    expect(challenge, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));

    await farmState.handleAuthFragment('code=${'d' * 64}');

    expect(fake.redeemedCodes.single.$1, 'd' * 64);
    expect(codeChallengeFor(fake.redeemedCodes.single.$2), challenge);
    expect(farmState.isLoggedIn, isTrue);
  });

  test('an expired session does not overwrite the saved guest farm', () async {
    farmState.coins = 123;
    await farmState.saveNow();
    fake.serverState = <String, Object?>{'coins': 5000};
    await farmState.applyAuthSession(fakeSession());
    fake.actionResult = (_) => ChainResult.unauthorized('Sesi habis, masuk lagi.');

    farmState.performPlotAction(0);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(farmState.isLoggedIn, isFalse);
    expect(farmState.coins, 123);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('taniin.farmState.v1'), contains('"coins":123'));
  });

  test('guests buy seeds with Game Coin, not TANI', () async {
    final taniBefore = farmState.tani;
    expect(farmState.buySeeds(0), isTrue);
    expect(farmState.coins, 620 - 100);
    expect(farmState.tani, taniBefore);
    expect(farmState.seeds[0].quantity, 6 + 3);
  });

  test('a guest without enough coins cannot buy seeds', () async {
    farmState.coins = 50;
    expect(farmState.buySeeds(2), isFalse);
    expect(farmState.statusMessage, contains('Koin'));
    expect(farmState.coins, 50);
  });

  test('opening the swap house starts with a small amount, not everything', () {
    farmState.prepareSwapAmount();
    expect(farmState.selectedSwapAmount, 100);
    farmState.coins = 40;
    farmState.swapAmount = 0;
    farmState.prepareSwapAmount();
    expect(farmState.selectedSwapAmount, 40);
  });
}

