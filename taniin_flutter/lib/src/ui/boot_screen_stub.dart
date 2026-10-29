import 'dart:async';

import '../chain/platform_bridge.dart';

/// Android: fades out the native loading card from MainActivity, which stays
/// above Flutter until the loading screen's images are decoded.
void hideBootScreen() {
  unawaited(PlatformBridge.hideNativeSplash());
}
