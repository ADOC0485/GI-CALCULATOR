import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/updates/app_update.dart';
import 'package:genshin_progress_planner/features/updates/update_widgets.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+\d+', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(appVersion, version);
  });

  test('Versions compare by number, ignoring the leading v', () {
    expect(compareVersions('v0.10.0', '0.9.9'), greaterThan(0));
    expect(compareVersions('v0.2.0', '0.2.0'), 0);
    expect(compareVersions('0.2', '0.2.1'), lessThan(0));
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
  });

  test('Reads the latest release and its APK from GitHub', () {
    final release = parseRelease({
      'tag_name': 'v0.3.0',
      'html_url': 'https://github.com/ADOC0485/GI-CALCULATOR/releases/tag/v0.3.0',
      'body': 'Ícono nuevo',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt'},
        {
          'name': 'GenshinProgressPlanner-v0.3.0.apk',
          'browser_download_url': 'https://x/app.apk',
        },
      ],
    })!;
    expect(release.version, 'v0.3.0');
    expect(release.apkUrl, 'https://x/app.apk');
    expect(release.isNewerThan('0.2.0'), isTrue);
    expect(release.isNewerThan('0.3.0'), isFalse);
    expect(parseRelease({'tag_name': 'v1', 'html_url': 'x', 'draft': true}), isNull);
  });

  Future<void> mount(WidgetTester tester, AppRelease? release) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [latestReleaseProvider.overrideWith((ref) async => release)],
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [UpdateBanner(), AboutCard()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('A newer release shows the banner until «Ahora no»', (tester) async {
    await mount(
      tester,
      const AppRelease(version: 'v9.0.0', pageUrl: 'https://example.com'),
    );
    expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
    expect(find.textContaining('Hay una versión nueva en GitHub'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
  });

  testWidgets('Same version: no banner', (tester) async {
    await mount(
      tester,
      const AppRelease(version: 'v$appVersion', pageUrl: 'https://example.com'),
    );
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    expect(find.text('Tienes la última versión publicada.'), findsOneWidget);
  });

  testWidgets('Without GitHub (offline): no banner, a calm message', (tester) async {
    await mount(tester, null);
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    expect(find.textContaining('No se pudo consultar GitHub'), findsOneWidget);
  });
}
