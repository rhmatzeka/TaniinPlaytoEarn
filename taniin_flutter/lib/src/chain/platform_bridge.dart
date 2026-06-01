import 'package:flutter/services.dart';

import 'chain_client.dart';

class PlatformBridge {
  PlatformBridge._();

  static const MethodChannel _channel = MethodChannel('taniin/platform');

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
    try {
      final raw = await _channel.invokeMethod<Object?>('getChainConfig');
      if (raw is Map<Object?, Object?>) {
        return ChainConfig.fromMap(raw);
      }
      if (raw is Map<dynamic, dynamic>) {
        return ChainConfig.fromMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException {
      return const ChainConfig();
    } on PlatformException {
      return const ChainConfig();
    }
    return const ChainConfig();
  }

  static Future<bool> openUrl(String url) async {
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
    nextParams['return'] = 'taniin://wallet';
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
}
