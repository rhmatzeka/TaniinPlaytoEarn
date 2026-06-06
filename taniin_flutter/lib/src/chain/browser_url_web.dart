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
