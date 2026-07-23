import 'dart:js_interop';

@JS('taniinHasEthereumProvider')
external bool _hasEthereumProvider();

@JS('taniinEthereumError')
external JSString _ethereumError();

@JS('taniinRequestEthereumAccount')
external JSPromise<JSString> _requestEthereumAccount();

@JS('taniinSendEthereum')
external JSPromise<JSString> _sendEthereum(JSString from, JSString to, JSString valueHex);

bool hasBrowserWalletProvider() {
  try {
    return _hasEthereumProvider();
  } on Object {
    return false;
  }
}

String browserWalletError() {
  try {
    return _ethereumError().toDart.trim();
  } on Object {
    return '';
  }
}

Future<String> requestBrowserWalletAddress() async {
  try {
    final address = await _requestEthereumAccount().toDart;
    return address.toDart.trim();
  } on Object {
    return '';
  }
}

Future<String> sendBrowserWalletEthereum(String from, String to, BigInt valueWei) async {
  try {
    final hash = await _sendEthereum(from.toJS, to.toJS, '0x${valueWei.toRadixString(16)}'.toJS).toDart;
    return hash.toDart.trim();
  } on Object {
    return '';
  }
}
