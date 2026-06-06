import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'browser_url.dart';
import 'chain_client.dart';

class PlatformBridge {
  PlatformBridge._();

  static const MethodChannel _channel = MethodChannel('taniin/platform');
  static const String _envRpcUrl = String.fromEnvironment(
    'SEPOLIA_RPC_URL',
    defaultValue: 'https://ethereum-sepolia-rpc.publicnode.com',
  );
  static const String _envCoinContractAddress = String.fromEnvironment(
    'TANIIN_COIN_CONTRACT_ADDRESS',
  );
  static const String _envItemsContractAddress = String.fromEnvironment(
    'TANIIN_ITEMS_CONTRACT_ADDRESS',
  );
  static const String _envLandContractAddress = String.fromEnvironment(
    'TANIIN_LAND_CONTRACT_ADDRESS',
  );
  static const String _envGameApiUrl = String.fromEnvironment(
    'TANIIN_GAME_API_URL',
  );
  static const String _envDefaultWalletAddress = String.fromEnvironment(
    'TANIIN_DEFAULT_WALLET_ADDRESS',
  );

  static void setWalletAddressHandler(void Function(String address)? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'walletAddress') {
        final address = call.arguments?.toString().trim() ?? '';
        if (address.isNotEmpty) {
          handler(address);
        }
      }
    });
  }

  static Future<ChainConfig> loadChainConfig() async {
    if (kIsWeb) {
      return _environmentChainConfig();
    }
    try {
      final raw = await _channel.invokeMethod<Object?>('getChainConfig');
      if (raw is Map<Object?, Object?>) {
        return ChainConfig.fromMap(raw);
      }
      if (raw is Map<dynamic, dynamic>) {
        return ChainConfig.fromMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException {
      return _environmentChainConfig();
    } on PlatformException {
      return _environmentChainConfig();
    }
    return _environmentChainConfig();
  }

  static Future<bool> openUrl(String url) async {
    if (kIsWeb) {
      return openBrowserUrl(url, sameTab: _isWalletConnectUrl(url));
    }
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openUrl',
        <String, Object>{'url': url},
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String> clipboardWalletAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    return firstWalletAddressInText(text);
  }

  static String launchWalletAddress() {
    if (!kIsWeb) {
      return '';
    }
    final address = Uri.base.queryParameters['address']?.trim() ?? '';
    return isValidAddress(address) ? address : '';
  }

  static String firstWalletAddressInText(String text) {
    final lower = text.toLowerCase();
    var from = 0;
    while (from < lower.length) {
      final start = lower.indexOf('0x', from);
      if (start < 0) {
        return '';
      }
      final end = start + 42;
      if (end <= text.length) {
        final candidate = text.substring(start, end);
        if (isValidAddress(candidate)) {
          return candidate;
        }
      }
      from = start + 2;
    }
    return '';
  }

  static String walletConnectUrl(ChainConfig config) {
    final baseUrl = config.walletConnectUrl;
    if (baseUrl.isEmpty) {
      return '';
    }
    final uri = Uri.parse(baseUrl);
    final nextParams = Map<String, String>.from(uri.queryParameters);
    nextParams['return'] = _walletReturnUrl();
    return uri.replace(queryParameters: nextParams).toString();
  }

  static String metamaskWalletConnectUrl(ChainConfig config) {
    final connectUrl = walletConnectUrl(config);
    if (connectUrl.isEmpty) {
      return '';
    }
    final uri = Uri.parse(connectUrl);
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    return 'https://metamask.app.link/dapp/${uri.host}$port$path';
  }

  static ChainConfig _environmentChainConfig() {
    return ChainConfig.fromMap(<Object?, Object?>{
      'rpcUrl': _envRpcUrl,
      'coinContractAddress': _envCoinContractAddress,
      'itemsContractAddress': _envItemsContractAddress,
      'landContractAddress': _envLandContractAddress,
      'gameApiUrl': _environmentGameApiUrl(),
      'defaultWalletAddress': _envDefaultWalletAddress,
    });
  }

  static String _environmentGameApiUrl() {
    final configured = _envGameApiUrl.trim();
    if (configured.isNotEmpty || !kIsWeb) {
      return configured;
    }
    final base = Uri.base;
    if (base.host.isEmpty ||
        (base.scheme != 'http' && base.scheme != 'https')) {
      return '';
    }
    final port = base.hasPort ? ':${base.port}' : '';
    return '${base.scheme}://${base.host}$port';
  }

  static String _walletReturnUrl() {
    if (!kIsWeb) {
      return 'taniin://wallet';
    }
    return Uri.base.replace(queryParameters: <String, String>{}).toString();
  }

  static bool _isWalletConnectUrl(String url) {
    try {
      return Uri.parse(url).path.endsWith('/wallet-connect');
    } on FormatException {
      return false;
    }
  }
}
