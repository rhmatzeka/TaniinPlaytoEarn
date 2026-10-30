bool openBrowserUrl(String url, {bool sameTab = false}) {
  return false;
}

void removeBrowserQueryParameters(Iterable<String> names) {}

String takeBrowserFragment() => '';

bool openInPageLogin(String state) => false;

void listenInPageLogin({
  required void Function(String fragment) onAuth,
  required void Function() onFailed,
}) {}
