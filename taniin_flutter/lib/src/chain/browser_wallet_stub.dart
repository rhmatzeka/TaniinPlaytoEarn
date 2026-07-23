bool hasBrowserWalletProvider() => false;

String browserWalletError() => '';

Future<String> requestBrowserWalletAddress() async => '';

Future<String> sendBrowserWalletEthereum(String from, String to, BigInt valueWei) async => '';
