export 'app_update_stub.dart' if (dart.library.io) 'app_update_io.dart';

/// Build number baked in by the Android APK workflow (`--dart-define`);
/// 0 on web and local builds.
const int appBuild = int.fromEnvironment('TANIIN_BUILD');

/// Where players get the latest APK.
const String apkDownloadUrl = 'https://taniin.rahmateka.my.id/unduh';

class AppUpdate {
  const AppUpdate({required this.build, required this.versionName});

  final int build;
  final String versionName;
}
