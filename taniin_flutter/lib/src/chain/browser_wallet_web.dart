import 'dart:js_interop';

@JS('taniinHasEthereumProvider')
external bool _hasEthereumProvider();

@JS('taniinEthereumError')
external JSString _ethereumError();

@JS('taniinRequestEthereumAccount')
external JSPromise<JSString> _requestEthereumAccount();

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
