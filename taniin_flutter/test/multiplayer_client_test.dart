import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taniin_flutter/src/chain/multiplayer_client.dart';
import 'package:taniin_flutter/src/state/farm_state.dart';

class _CountingClient extends MultiplayerClient {
  _CountingClient(super.farmState);

  int reconnects = 0;

  @override
  void reconnect() {
    reconnects += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chatting while offline does not force a reconnect per message', () {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final farmState = FarmStateController();
    final client = _CountingClient(farmState);
    client.sendChat('halo');
    client.sendChat('halo lagi');
    expect(client.reconnects, 0);
    expect(client.chatMessages.where((m) => m.sender == 'Kamu'), hasLength(2));
  });
}
