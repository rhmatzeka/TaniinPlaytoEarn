import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String sepoliaExplorerTxBase = 'https://sepolia.etherscan.io/tx/';

class ChainConfig {
  const ChainConfig({
    this.rpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com',
    this.coinContractAddress = '',
    this.itemsContractAddress = '',
    this.landContractAddress = '',
    this.gameApiUrl = '',
    this.defaultWalletAddress = '',
  });

  factory ChainConfig.fromMap(Map<Object?, Object?> map) {
    return ChainConfig(
      rpcUrl: _stringValue(
        map['rpcUrl'],
        fallback: 'https://ethereum-sepolia-rpc.publicnode.com',
      ),
      coinContractAddress: _cleanAddress(map['coinContractAddress']),
      itemsContractAddress: _cleanAddress(map['itemsContractAddress']),
      landContractAddress: _cleanAddress(map['landContractAddress']),
      gameApiUrl: _trimTrailingSlash(_stringValue(map['gameApiUrl'])),
      defaultWalletAddress: _cleanAddress(map['defaultWalletAddress']),
    );
  }

  final String rpcUrl;
  final String coinContractAddress;
  final String itemsContractAddress;
  final String landContractAddress;
  final String gameApiUrl;
  final String defaultWalletAddress;

  bool get hasCoinContract => coinContractAddress.isNotEmpty;

  bool get hasGameApi => gameApiUrl.isNotEmpty;

  String get walletConnectUrl => hasGameApi ? '$gameApiUrl/wallet-connect' : '';

  String contractSummary() {
    final coin = hasCoinContract
        ? shortAddress(coinContractAddress)
        : 'TANI belum diset';
    final items = itemsContractAddress.isEmpty
        ? 'Items belum diset'
        : shortAddress(itemsContractAddress);
    final land = landContractAddress.isEmpty
        ? 'Land belum diset'
        : shortAddress(landContractAddress);
    return 'Coin $coin | Items $items | Land $land';
  }
}

class ChainAction {
  ChainAction({required this.type, required this.plotId, required this.amount})
    : createdAtMs = DateTime.now().millisecondsSinceEpoch;

  final String type;
  final int plotId;
  final int amount;
  final int createdAtMs;

  String get label {
    return switch (type) {
      'BUY_LAND' => 'Mint lahan #$plotId',
      'SELL_LAND' => 'Jual lahan #$plotId',
      'PLANT' => 'Tanam lahan #$plotId',
      'HARVEST' => 'Claim panen $amount',
      'SELL_CROP' => 'Jual panen $amount',
      'SWAP_CROP' => 'Swap panen $amount',
      'SWAP_COIN' => 'Swap coin $amount',
      'SWAP_TANI_COIN' => 'Deposit TANI ke Game Coin $amount',
      'SWAP_COIN_ETH' => 'Swap coin ke ETH $amount',
      'SWAP_ETH_COIN' => 'Isi Game Coin dari ETH $amount',
      'BUY_SEED' => 'Beli bibit $amount',
      _ => type,
    };
  }

  Map<String, Object> toGameApiJson(String walletAddress) {
    return <String, Object>{
      'wallet': walletAddress,
      'type': type,
      'plotId': plotId,
      'amount': amount,
      'createdAtMs': createdAtMs,
    };
  }
}

class ChainResult {
  const ChainResult({
    required this.success,
    required this.message,
    this.txHash = '',
  });

  factory ChainResult.ok(String message, {String txHash = ''}) {
    return ChainResult(success: true, message: message, txHash: txHash.trim());
  }

  factory ChainResult.error(String message) {
    return ChainResult(success: false, message: message);
  }

  final bool success;
  final String message;
  final String txHash;
}

class ChainWalletState {
  const ChainWalletState({
    required this.success,
    required this.message,
    this.coinBalance = 0,
    this.coinBalanceAvailable = false,
    this.nativeEth = '',
    this.signerAddress = '',
  });

  factory ChainWalletState.ok({
    required String message,
    required int coinBalance,
    required bool coinBalanceAvailable,
    required String nativeEth,
    required String signerAddress,
  }) {
    return ChainWalletState(
      success: true,
      message: message,
      coinBalance: coinBalance,
      coinBalanceAvailable: coinBalanceAvailable,
      nativeEth: nativeEth,
      signerAddress: signerAddress,
    );
  }

  factory ChainWalletState.error(String message) {
    return ChainWalletState(success: false, message: message);
  }

  final bool success;
  final String message;
  final int coinBalance;
  final bool coinBalanceAvailable;
  final String nativeEth;
  final String signerAddress;
}

class ChainClient {
  ChainClient(this.config);

  static const String sepoliaChainIdHex = '0xaa36a7';
  static const String sepoliaChainIdLabel = '11155111';
  static final BigInt _weiPerEth = BigInt.parse('1000000000000000000');
  static const Duration _timeout = Duration(seconds: 9);

  final ChainConfig config;

  Future<ChainResult> checkSepolia() async {
    try {
      final chainId = await _rpcResult(<String, Object>{
        'jsonrpc': '2.0',
        'method': 'eth_chainId',
        'params': <Object>[],
        'id': 1,
      });
      final sepolia = chainId.toLowerCase() == sepoliaChainIdHex;
      return sepolia
          ? ChainResult.ok('Sepolia RPC online. Chain ID $sepoliaChainIdLabel.')
          : ChainResult.error('RPC online, tapi chain ID bukan Sepolia.');
    } on Object catch (error) {
      return ChainResult.error('Gagal cek Sepolia: $error');
    }
  }

  Future<ChainWalletState> loadWalletState(String walletAddress) async {
    final wallet = walletAddress.trim();
    if (!isValidAddress(wallet)) {
      return ChainWalletState.error('Wallet address tidak valid.');
    }
    try {
      final network = await checkSepolia();
      final nativeWei = await _ethGetBalance(wallet);
      final nativeEth = _formatEth(nativeWei);
      var signerAddress = '';
      try {
        signerAddress = await _loadGameApiSignerAddress();
      } on Object {
        signerAddress = '';
      }
      if (config.hasCoinContract) {
        final rawCoin = await _erc20BalanceOf(
          config.coinContractAddress,
          wallet,
        );
        final wholeCoin = _clampToGameCoin(rawCoin ~/ _weiPerEth);
        return ChainWalletState.ok(
          message: '${network.message} TANI $wholeCoin | ETH $nativeEth',
          coinBalance: wholeCoin,
          coinBalanceAvailable: true,
          nativeEth: nativeEth,
          signerAddress: signerAddress,
        );
      }
      return ChainWalletState.ok(
        message:
            '${network.message} ETH $nativeEth. Contract TANI belum diset, coin masih lokal.',
        coinBalance: 0,
        coinBalanceAvailable: false,
        nativeEth: nativeEth,
        signerAddress: signerAddress,
      );
    } on Object catch (error) {
      final signerAddress = await _loadGameApiSignerAddress();
      if (config.hasGameApi) {
        return ChainWalletState.ok(
          message:
              'Wallet tersambung. API Sepolia aktif; saldo RPC belum kebaca di device.',
          coinBalance: 0,
          coinBalanceAvailable: false,
          nativeEth: '',
          signerAddress: signerAddress,
        );
      }
      return ChainWalletState.error(
        'Gagal sync wallet: ${_compactError(error)}',
      );
    }
  }

  Future<ChainResult> submitGameAction(
    String walletAddress,
    ChainAction action,
  ) async {
    try {
      if (!config.hasGameApi) {
        return ChainResult.error(
          'TANIIN_GAME_API_URL belum diset; aksi belum dikirim on-chain.',
        );
      }
      if (!isValidAddress(walletAddress)) {
        return ChainResult.error(
          'Wallet belum valid; aksi belum dikirim on-chain.',
        );
      }
      final body = jsonEncode(action.toGameApiJson(walletAddress));
      final response = await _postGameApi('/game-actions', body);
      final apiError = extractApiError(response);
      if (apiError.isNotEmpty) {
        return ChainResult.error(apiError);
      }
      final txHash = extractTransactionHash(response);
      return txHash.isEmpty
          ? ChainResult.ok(
              'Aksi dikirim, tapi backend belum mengembalikan txHash.',
            )
          : ChainResult.ok(
              'Transaksi dikirim ke Sepolia: ${shortTransactionHash(txHash)}.',
              txHash: txHash,
            );
    } on Object catch (error) {
      return ChainResult.error('Gagal kirim aksi chain: $error');
    }
  }

  Future<String> _rpcResult(Map<String, Object> payload) async {
    final response = await _postJson(config.rpcUrl, jsonEncode(payload));
    final object = jsonDecode(response) as Map<String, dynamic>;
    final error = object['error'];
    if (error is Map<String, dynamic>) {
      throw StateError(error['message']?.toString() ?? error.toString());
    }
    return object['result']?.toString() ?? '';
  }

  Future<BigInt> _ethGetBalance(String walletAddress) async {
    final result = await _rpcResult(<String, Object>{
      'jsonrpc': '2.0',
      'method': 'eth_getBalance',
      'params': <Object>[walletAddress, 'latest'],
      'id': 2,
    });
    return _hexToBigInt(result);
  }

  Future<BigInt> _erc20BalanceOf(
    String contractAddress,
    String walletAddress,
  ) async {
    final result = await _rpcResult(<String, Object>{
      'jsonrpc': '2.0',
      'method': 'eth_call',
      'params': <Object>[
        <String, String>{
          'to': contractAddress,
          'data': _erc20BalanceOfData(walletAddress),
        },
        'latest',
      ],
      'id': 3,
    });
    return _hexToBigInt(result);
  }

  Future<String> _loadGameApiSignerAddress() async {
    if (!config.hasGameApi) {
      return '';
    }
    try {
      final response = await _getGameApi('/health');
      final object = jsonDecode(response) as Map<String, dynamic>;
      return _cleanAddress(object['signer']);
    } on Object {
      return '';
    }
  }

  Future<String> _postGameApi(String path, String payload) async {
    Object? lastError;
    for (final baseUrl in _gameApiUrlCandidates()) {
      try {
        return await _postJson('$baseUrl$path', payload);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw StateError(lastError?.toString() ?? 'Game API tidak valid.');
  }

  Future<String> _getGameApi(String path) async {
    Object? lastError;
    for (final baseUrl in _gameApiUrlCandidates()) {
      try {
        return await _getJson('$baseUrl$path');
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw StateError(lastError?.toString() ?? 'Game API tidak valid.');
  }

  List<String> _gameApiUrlCandidates() {
    final fallback = _localGameApiFallback(config.gameApiUrl);
    if (fallback.isEmpty || fallback == config.gameApiUrl) {
      return <String>[config.gameApiUrl];
    }
    return <String>[config.gameApiUrl, fallback];
  }

  static Future<String> _postJson(String url, String payload) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(Uri.parse(url)).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      final body = utf8.encode(payload);
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(_timeout);
      return await _readHttpResponse(response);
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      return await _readHttpResponse(response);
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _readHttpResponse(HttpClientResponse response) async {
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final apiError = extractApiError(body);
      throw StateError(
        'HTTP ${response.statusCode}${apiError.isEmpty ? ' $body' : ' $apiError'}',
      );
    }
    return body;
  }

  static String _erc20BalanceOfData(String walletAddress) {
    final clean = walletAddress.substring(2).toLowerCase();
    return '0x70a08231${clean.padLeft(64, '0')}';
  }

  static BigInt _hexToBigInt(String value) {
    final cleaned = value.trim();
    if (!cleaned.startsWith('0x') || cleaned.length <= 2) {
      return BigInt.zero;
    }
    return BigInt.parse(cleaned.substring(2), radix: 16);
  }

  static String _formatEth(BigInt wei) {
    final whole = wei ~/ _weiPerEth;
    final fraction = wei.remainder(_weiPerEth);
    if (fraction == BigInt.zero) {
      return whole.toString();
    }
    final fractionText = fraction.toString().padLeft(18, '0').substring(0, 12);
    final compactFraction = fractionText.replaceFirst(RegExp(r'0+$'), '');
    return compactFraction.isEmpty
        ? whole.toString()
        : '$whole.$compactFraction';
  }

  static int _clampToGameCoin(BigInt value) {
    if (value < BigInt.zero) {
      return 0;
    }
    final max = BigInt.from(0x7fffffff);
    if (value > max) {
      return 0x7fffffff;
    }
    return value.toInt();
  }
}

bool isValidAddress(String address) {
  return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address.trim());
}

bool isValidTransactionHash(String hash) {
  return RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash.trim());
}

String shortAddress(String address) {
  final cleaned = address.trim();
  if (cleaned.length < 12) {
    return cleaned;
  }
  return '${cleaned.substring(0, 6)}...${cleaned.substring(cleaned.length - 4)}';
}

String shortTransactionHash(String hash) {
  final cleaned = hash.trim();
  if (!isValidTransactionHash(cleaned)) {
    return '';
  }
  return '${cleaned.substring(0, 10)}...${cleaned.substring(cleaned.length - 6)}';
}

String transactionUrl(String hash) => '$sepoliaExplorerTxBase$hash';

String extractTransactionHash(String response) {
  final cleaned = response.trim();
  if (isValidTransactionHash(cleaned)) {
    return cleaned;
  }
  if (cleaned.isEmpty) {
    return '';
  }
  try {
    final object = jsonDecode(cleaned);
    if (object is Map<String, dynamic>) {
      final direct = _firstValidTransactionHash(<Object?>[
        object['txHash'],
        object['transactionHash'],
        object['hash'],
        object['result'],
      ]);
      if (direct.isNotEmpty) {
        return direct;
      }
      for (final key in <String>['data', 'result']) {
        final nested = object[key];
        if (nested is Map<String, dynamic>) {
          final nestedHash = _firstValidTransactionHash(<Object?>[
            nested['txHash'],
            nested['transactionHash'],
            nested['hash'],
          ]);
          if (nestedHash.isNotEmpty) {
            return nestedHash;
          }
        }
      }
      final hashes = object['txHashes'];
      if (hashes is List<Object?>) {
        final arrayHash = _firstValidTransactionHash(hashes);
        if (arrayHash.isNotEmpty) {
          return arrayHash;
        }
      }
    }
  } on Object {
    return '';
  }
  return '';
}

String extractApiError(String response) {
  final cleaned = response.trim();
  if (cleaned.isEmpty) {
    return '';
  }
  try {
    final object = jsonDecode(cleaned);
    if (object is! Map<String, dynamic>) {
      return '';
    }
    if (object['ok'] == true || !object.containsKey('ok')) {
      return '';
    }
    final error = object['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) {
      return error;
    }
    return object['message']?.toString().trim() ?? '';
  } on Object {
    return '';
  }
}

String _firstValidTransactionHash(Iterable<Object?> values) {
  for (final value in values) {
    final cleaned = value?.toString().trim() ?? '';
    if (isValidTransactionHash(cleaned)) {
      return cleaned;
    }
  }
  return '';
}

String _stringValue(Object? value, {String fallback = ''}) {
  final cleaned = value?.toString().trim() ?? '';
  return cleaned.isEmpty ? fallback : cleaned;
}

String _cleanAddress(Object? value) {
  final cleaned = _stringValue(value);
  return isValidAddress(cleaned) ? cleaned : '';
}

String _trimTrailingSlash(String value) {
  var cleaned = value.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  return cleaned;
}

String _compactError(Object error) {
  final text = error.toString().replaceFirst('StateError: ', '').trim();
  return text.length > 72 ? '${text.substring(0, 69)}...' : text;
}

String _localGameApiFallback(String url) {
  if (url.startsWith('http://127.0.0.1:')) {
    return 'http://10.0.2.2:${url.substring('http://127.0.0.1:'.length)}';
  }
  if (url.startsWith('http://localhost:')) {
    return 'http://10.0.2.2:${url.substring('http://localhost:'.length)}';
  }
  if (url.startsWith('http://10.0.2.2:')) {
    return 'http://127.0.0.1:${url.substring('http://10.0.2.2:'.length)}';
  }
  return '';
}
