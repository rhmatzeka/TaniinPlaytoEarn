import 'package:taniin_flutter/src/chain/auth_session.dart';
import 'package:taniin_flutter/src/chain/chain_client.dart';

const String fakeTxHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const String fakeWallet = '0x0000000000000000000000000000000000000001';

AuthSession fakeSession({String wallet = fakeWallet}) {
  return AuthSession(
    token: 'a' * 64,
    wallet: wallet,
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    loginMethod: 'email',
  );
}

class FakeChainClient extends ChainClient {
  FakeChainClient(super.config);

  final List<ChainAction> actions = <ChainAction>[];
  final List<String> idempotencyKeys = <String>[];
  final List<Map<String, Object?>> imports = <Map<String, Object?>>[];
  ChainReceiptState receiptState = ChainReceiptState.ok('Confirmed fake.');
  ChainResult Function(ChainAction action)? actionResult;
  Map<String, Object?> serverState = <String, Object?>{'coins': 620};
  bool importedGuest = false;
  String nativeEth = '0.001';
  String nativeWei = '1000000000000000';
  String ethWeiPerCoin = '10000000000';
  String maxEthPayoutWei = '1000000000000';
  int walletLoads = 0;
  int logouts = 0;
  final List<(String, String)> redeemedCodes = <(String, String)>[];

  @override
  Future<ChainResult> submitGameAction(
    AuthSession session,
    ChainAction action,
    String idempotencyKey,
  ) async {
    actions.add(action);
    idempotencyKeys.add(idempotencyKey);
    final custom = actionResult;
    if (custom != null) {
      return custom(action);
    }
    return ChainResult.ok(
      'Transaksi fake terkirim.',
      txHash: fakeTxHash,
      state: serverState,
    );
  }

  @override
  Future<ServerPlayerResult> fetchPlayer(AuthSession session) async {
    return ServerPlayerResult.ok(serverState, importedGuest: importedGuest);
  }

  @override
  Future<ServerPlayerResult> importGuest(
    AuthSession session,
    Map<String, Object?> guestState,
  ) async {
    imports.add(guestState);
    importedGuest = true;
    return ServerPlayerResult.ok(serverState, importedGuest: true);
  }

  @override
  Future<AuthSession?> redeemLoginCode(String code, String verifier) async {
    redeemedCodes.add((code, verifier));
    return fakeSession();
  }

  @override
  Future<void> logout(AuthSession session) async {
    logouts += 1;
  }

  @override
  Future<ChainResult> checkSepolia() async => ChainResult.ok('Sepolia fake.');

  @override
  Future<bool> checkGameApi() async => true;

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
