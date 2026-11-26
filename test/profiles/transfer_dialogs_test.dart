import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/profiles/lan_transfer.dart';
import 'package:genshin_progress_planner/features/profiles/profile.dart';
import 'package:genshin_progress_planner/features/profiles/profiles_card.dart';
import 'package:genshin_progress_planner/features/progression/data/scenario_repository.dart';

void main() {
  const port = 47898;

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    List<int>? received,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileSenderProvider.overrideWithValue(
          (payload) => ProfileSender.start(
            payload,
            host: 1,
            bindAddress: InternetAddress.loopbackIPv4,
            port: port,
          ),
        ),
        if (received != null)
          profileReceiverProvider.overrideWithValue((_) async => received),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ProfilesCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Sending shows a code that the other device can use', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Perfiles (1/5)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-send')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('send-start')));
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byKey(const ValueKey('send-code')).evaluate().isNotEmpty) {
          break;
        }
      }
      final code = tester
          .widget<SelectableText>(find.byKey(const ValueKey('send-code')))
          .data!;
      final bytes = await receiveProfile(
        code,
        addresses: [InternetAddress.loopbackIPv4],
        port: port,
      );
      expect(
        ProfilesController.readPackage(decodePackage(bytes)).name,
        'Viajero',
      );
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    expect(
      find.text('¡Listo! El perfil llegó al otro dispositivo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
  });

  testWidgets('Receiving the same profile again asks before replacing', (
    tester,
  ) async {
    // The package comes from another device that already sent it once.
    final otherDb = AppDatabase(NativeDatabase.memory());
    addTearDown(otherDb.close);
    final other = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(otherDb)],
    );
    addTearDown(other.dispose);
    await other.read(profilesProvider.future);
    final package = await other
        .read(profilesProvider.notifier)
        .exportPackage(defaultProfileId);

    final container = await mount(tester, received: encodePackage(package));
    await container.read(profilesProvider.notifier).importPackage(package);
    await tester.pumpAndSettle();
    expect(find.text('Perfiles (2/5)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-receive')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('receive-code')),
      '001 234 567',
    );
    await tester.tap(find.byKey(const ValueKey('receive-start')));
    // The progress bar keeps moving while the question is open.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Ya tienes el perfil de Viajero (copia)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('receive-replace')));
    await tester.pumpAndSettle();
    expect(find.text('¡Listo! Llegó el perfil de Viajero.'), findsOneWidget);
    // Replaced in place: still two profiles.
    expect(find.text('Perfiles (2/5)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
