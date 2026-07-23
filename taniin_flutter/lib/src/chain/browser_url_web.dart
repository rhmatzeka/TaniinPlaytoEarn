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
