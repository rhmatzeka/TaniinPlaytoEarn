import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool openBrowserUrl(String url, {bool sameTab = false}) {
  final cleaned = url.trim();
  if (cleaned.isEmpty) {
    return false;
  }
  if (sameTab) {
    web.window.location.assign(cleaned);
  } else {
    web.window.open(cleaned, '_blank');
  }
  return true;
}

void removeBrowserQueryParameters(Iterable<String> names) {
  final uri = Uri.base;
  final parameters = Map<String, String>.from(uri.queryParameters);
  var changed = false;
  for (final name in names) {
    changed = parameters.remove(name) != null || changed;
  }
  if (!changed) {
    return;
  }
  final cleaned = uri.replace(queryParameters: parameters.isEmpty ? null : parameters);
  web.window.history.replaceState(null, '', cleaned.toString());
}

/// Reads and clears the URL fragment the login page redirected back with.
String takeBrowserFragment() {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) {
    return '';
  }
  final cleaned = Uri.base.removeFragment();
  web.window.history.replaceState(null, '', cleaned.toString());
  return fragment;
}

/// Opens the Privy login over the game page (see web/index.html). False if
/// the page has no in-page login, so the caller can fall back to /masuk.
bool openInPageLogin(String state) {
  final open = globalContext['taniinOpenLogin'];
  if (open == null || !open.isA<JSFunction>()) {
    return false;
  }
  (open as JSFunction).callAsFunction(null, state.toJS);
  return true;
}

/// Delivers in-page login results: the session fragment (also one that
/// arrived before the game was listening), or a failure to load the login.
void listenInPageLogin({
  required void Function(String fragment) onAuth,
  required void Function() onFailed,
}) {
  void take() {
    final pending = globalContext['__taniinAuth'];
    if (pending != null && pending.isA<JSString>()) {
      globalContext['__taniinAuth'] = null;
      onAuth((pending as JSString).toDart);
    }
  }

  take();
  web.window.addEventListener('taniin-auth', ((web.Event _) => take()).toJS);
  web.window.addEventListener(
    'taniin-login-failed',
    ((web.Event _) => onFailed()).toJS,
  );
}
