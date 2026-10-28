import 'chain_client.dart';

final RegExp _sessionTokenPattern = RegExp(r'^[0-9a-f]{64}$');

/// A Taniin server session issued after a Privy login on the `/masuk` page.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.wallet,
    required this.expiresAt,
    required this.loginMethod,
  });

  final String token;
  final String wallet;
  final DateTime expiresAt;
  final String loginMethod;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool get isExpired => isExpiredAt(DateTime.now().toUtc());

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'wallet': wallet,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'loginMethod': loginMethod,
  };

  static AuthSession? fromJson(Map<String, Object?> json) {
    return _build(
      token: json['token']?.toString() ?? '',
      wallet: json['wallet']?.toString() ?? '',
      expires: json['expiresAt']?.toString() ?? '',
      method: json['loginMethod']?.toString() ?? '',
    );
  }

  /// Parses `session=...&wallet=...&expires=...&method=...` from the URL fragment
  /// the login page redirects back with. Returns null when anything is off.
  static AuthSession? fromFragment(String fragment, DateTime now) {
    final values = _fragmentValues(fragment);
    final session = _build(
      token: values['session'] ?? '',
      wallet: values['wallet'] ?? '',
      expires: values['expires'] ?? '',
      method: values['method'] ?? '',
    );
    if (session == null || session.isExpiredAt(now)) {
      return null;
    }
    return session;
  }

  static AuthSession? _build({
    required String token,
    required String wallet,
    required String expires,
    required String method,
  }) {
    final expiresAt = DateTime.tryParse(expires)?.toUtc();
    if (!_sessionTokenPattern.hasMatch(token) ||
        !isValidAddress(wallet) ||
        expiresAt == null) {
      return null;
    }
    return AuthSession(
      token: token,
      wallet: wallet,
      expiresAt: expiresAt,
      loginMethod: method.isEmpty ? 'privy' : method,
    );
  }
}

/// Result of the `/masuk?aksi=isi-eth` page: an ETH payment to the signer.
class FundCallback {
  const FundCallback({required this.txHash, required this.amount});

  final String txHash;
  final int amount;

  static FundCallback? fromFragment(String fragment) {
    final values = _fragmentValues(fragment);
    final txHash = values['fundTx'] ?? '';
    final amount = int.tryParse(values['jumlah'] ?? '');
    if (!isValidTransactionHash(txHash) || amount == null || amount <= 0) {
      return null;
    }
    return FundCallback(txHash: txHash, amount: amount);
  }
}

Map<String, String> _fragmentValues(String fragment) {
  final cleaned = fragment.startsWith('#') ? fragment.substring(1) : fragment;
  try {
    return Uri.splitQueryString(cleaned);
  } on FormatException {
    return const <String, String>{};
  }
}
