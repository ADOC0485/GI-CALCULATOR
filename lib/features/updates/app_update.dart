import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Version of this build. Keep it equal to `version:` in pubspec.yaml
/// (a test checks it); publishing bumps both.
const appVersion = '0.2.0';

/// Repository whose GitHub Releases carry new versions of the app.
const releasesRepository = 'ADOC0485/GI-CALCULATOR';
const releasesPage = 'https://github.com/$releasesRepository/releases';

/// A version published on GitHub Releases.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    this.apkUrl,
    this.notes = '',
  });
  final String version, pageUrl, notes;

  /// Direct download of the Android APK attached to the release, if any.
  final String? apkUrl;

  bool isNewerThan(String current) => compareVersions(version, current) > 0;
}

/// Compares "1.2.3" style versions (a leading "v" is ignored).
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first.split('.'))
      int.tryParse(p) ?? 0,
  ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}

/// Reads the response of GitHub's "latest release" API.
AppRelease? parseRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  final page = json['html_url'];
  if (tag is! String || page is! String || json['draft'] == true) return null;
  String? apk;
  for (final asset in (json['assets'] as List?) ?? const []) {
    if (asset is Map &&
        '${asset['name']}'.toLowerCase().endsWith('.apk') &&
        asset['browser_download_url'] is String) {
      apk = asset['browser_download_url'] as String;
      break;
    }
  }
  return AppRelease(
    version: tag,
    pageUrl: page,
    apkUrl: apk,
    notes: json['body'] is String ? json['body'] as String : '',
  );
}

/// Asks GitHub for the latest published release. Returns null when there is
/// none, or when GitHub cannot be reached (the app keeps working offline).
Future<AppRelease?> fetchLatestRelease({HttpClient Function()? client}) async {
  final http = (client ?? HttpClient.new)()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await http.getUrl(
      Uri.https('api.github.com', '/repos/$releasesRepository/releases/latest'),
    );
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'GI-Calculator')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    return parseRelease(jsonDecode(body) as Map<String, dynamic>);
  } catch (_) {
    return null;
  } finally {
    http.close(force: true);
  }
}

/// Latest release on GitHub; refresh it with `ref.invalidate`.
final latestReleaseProvider = FutureProvider<AppRelease?>(
  (ref) => fetchLatestRelease(),
);

/// Versions the player chose to skip for now (until the app restarts).
final dismissedUpdateProvider = NotifierProvider<DismissedUpdate, String?>(
  DismissedUpdate.new,
);

class DismissedUpdate extends Notifier<String?> {
  @override
  String? build() => null;
  void dismiss(String version) => state = version;
}
