import 'dart:convert';
import 'dart:io';

import 'app_update.dart';

// Uploaded next to Taniin.apk by .github/workflows/android.yml.
const _versionUrl =
    'https://github.com/rhmatzeka/TaniinPlaytoEarn/releases/download/apk-terbaru/versi.json';

/// Asks the apk-terbaru release whether a newer APK than this one exists.
/// Only CI-built Android APKs know their own build; anything else, and any
/// network or parse failure, answers null.
Future<AppUpdate?> checkForAppUpdate() async {
  if (appBuild <= 0 || !Platform.isAndroid) {
    return null;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(Uri.parse(_versionUrl));
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final build = (json['build'] as num?)?.toInt() ?? 0;
    if (build <= appBuild) {
      return null;
    }
    return AppUpdate(
      build: build,
      versionName: json['versi'] as String? ?? '1.0.$build',
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
