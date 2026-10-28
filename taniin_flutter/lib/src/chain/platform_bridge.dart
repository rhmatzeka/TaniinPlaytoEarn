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
  static const String _envMultiplayerUrl = String.fromEnvironment(
    'TANIIN_MULTIPLAYER_URL',
  );

  /// Android delivers `taniin://auth#...` fragments through this handler.
  static void setAuthCallbackHandler(void Function(String fragment)? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'authCallback') {
        final fragment = call.arguments?.toString().trim() ?? '';
        if (fragment.isNotEmpty) {
          handler(fragment);
        }
      }
    });
  }

  /// On web, the login page redirects back to the game with a URL fragment.
  static String launchAuthFragment() => kIsWeb ? takeBrowserFragment() : '';

  static Future<ChainConfig> loadChainConfig() async {
    if (kIsWeb) {
      return _environmentChainConfig();
    }
    try {
      final raw = await _channel.invokeMethod<Object?>('getChainConfig');
      if (raw is Map) {
        return ChainConfig.fromMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException {
      return _environmentChainConfig();
    } on PlatformException {
      return _environmentChainConfig();
    }
    return _environmentChainConfig();
  }

  static Future<bool> openUrl(String url, {bool sameTab = false}) async {
    if (kIsWeb) {
      return openBrowserUrl(url, sameTab: sameTab);
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

  /// `/masuk` page URL; web returns to the game path, Android to `taniin://auth`.
  static String loginUrl(
    ChainConfig config, {
    String aksi = 'masuk',
    int? jumlah,
    String? challenge,
    bool? forApp,
  }) {
    if (!config.hasGameApi) {
      return '';
    }
    final app = forApp ?? !kIsWeb;
    final returnUrl = app
        ? 'taniin://auth'
        : Uri.base.removeFragment().replace(queryParameters: null).path;
    return Uri.parse('${config.gameApiUrl}/masuk/').replace(
      queryParameters: <String, String>{
        'return': returnUrl,
        if (aksi != 'masuk') 'aksi': aksi,
        if (jumlah != null) 'jumlah': '$jumlah',
        'challenge': ?challenge,
      },
    ).toString();
  }

  static ChainConfig _environmentChainConfig() {
    return ChainConfig.fromMap(<Object?, Object?>{
      'rpcUrl': _envRpcUrl,
      'coinContractAddress': _envCoinContractAddress,
      'itemsContractAddress': _envItemsContractAddress,
      'landContractAddress': _envLandContractAddress,
      'gameApiUrl': _environmentGameApiUrl(),
      'multiplayerUrl': _envMultiplayerUrl,
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
}
