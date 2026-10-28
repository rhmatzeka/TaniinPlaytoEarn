import 'package:flutter_test/flutter_test.dart';
import 'package:taniin_flutter/src/chain/auth_session.dart';

const String _wallet = '0x1111111111111111111111111111111111111111';
const String _token =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  final now = DateTime.utc(2026, 10, 28, 10);

  String fragment({
    String session = _token,
    String wallet = _wallet,
    String expires = '2026-11-04T10:00:00.000Z',
  }) {
    return Uri(
      queryParameters: <String, String>{
        'session': session,
        'wallet': wallet,
        'expires': expires,
        'method': 'email',
      },
    ).query;
  }

  test('parses a valid login fragment', () {
    final session = AuthSession.fromFragment(fragment(), now);
    expect(session, isNotNull);
    expect(session!.token, _token);
    expect(session.wallet, _wallet);
    expect(session.loginMethod, 'email');
    expect(session.expiresAt, DateTime.utc(2026, 11, 4, 10));
    expect(session.isExpiredAt(now), isFalse);
  });

  test('rejects an invalid wallet', () {
    expect(AuthSession.fromFragment(fragment(wallet: '0x123'), now), isNull);
  });

  test('rejects an expired session', () {
    expect(
      AuthSession.fromFragment(
        fragment(expires: '2026-10-27T10:00:00.000Z'),
        now,
      ),
      isNull,
    );
  });

  test('rejects an empty or malformed token', () {
    expect(AuthSession.fromFragment(fragment(session: ''), now), isNull);
    expect(AuthSession.fromFragment(fragment(session: 'xyz'), now), isNull);
  });

  test('round-trips through JSON', () {
    final session = AuthSession.fromFragment(fragment(), now)!;
    final restored = AuthSession.fromJson(session.toJson());
    expect(restored, isNotNull);
    expect(restored!.token, session.token);
    expect(restored.wallet, session.wallet);
    expect(restored.expiresAt, session.expiresAt);
  });

  test('parses an ETH funding callback', () {
    const hash =
        '0xabababababababababababababababababababababababababababababababab';
    final callback = FundCallback.fromFragment('fundTx=$hash&jumlah=200');
    expect(callback, isNotNull);
    expect(callback!.txHash, hash);
    expect(callback.amount, 200);
    expect(FundCallback.fromFragment('fundTx=0x12&jumlah=200'), isNull);
    expect(FundCallback.fromFragment(fragment()), isNull);
  });
}
