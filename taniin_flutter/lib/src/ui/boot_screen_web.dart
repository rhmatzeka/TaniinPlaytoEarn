import 'package:web/web.dart' as web;

/// Fades out the HTML boot card from web/index.html. It sits above the
/// Flutter view until the loading screen's images are decoded, so the page
/// never flashes an empty frame. Safe to call more than once.
void hideBootScreen() {
  final boot = web.document.querySelector('.boot');
  if (boot == null || boot.classList.contains('boot--keluar')) {
    return;
  }
  boot.classList.add('boot--keluar');
  Future<void>.delayed(const Duration(milliseconds: 450), () => boot.remove());
}
