import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/profiles/lan_transfer.dart';
import 'package:genshin_progress_planner/features/profiles/profile.dart';
import 'package:genshin_progress_planner/features/progression/data/scenario_repository.dart';

void main() {
  final loopback = [InternetAddress.loopbackIPv4];
  // A port of its own so a real transfer open on this PC does not clash.
  const port = 47899;

  Future<ProfileSender> sender(List<int> payload) => ProfileSender.start(
    payload,
    host: 1,
    bindAddress: InternetAddress.loopbackIPv4,
    port: port,
  );

  test('The code has 9 digits and carries the address', () {
    final code = TransferCode.random(42);
    expect(code.digits, hasLength(9));
    expect(code.text, startsWith('042 '));
    expect(TransferCode.parse(code.text).secret, code.secret);
    expect(() => TransferCode.parse('123'), throwsA(isA<TransferException>()));
    expect(
      () => TransferCode.parse('999123456'),
      throwsA(isA<TransferException>()),
    );
  });

  test('With the right code the data arrives', () async {
    final payload = List.generate(200000, (i) => i % 251);
    final s = await sender(payload);
    final received = await receiveProfile(
      s.code.text,
      addresses: loopback,
      port: port,
    );
    expect(received, payload);
    // The sender hears the confirmation right after.
    for (var i = 0; i < 100 && s.current.stage != SendStage.done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(s.current.stage, SendStage.done);
  });

  test('Three wrong codes close the sender', () async {
    final s = await sender([1, 2, 3]);
    final wrong = '001${s.code.secret == '000000' ? '111111' : '000000'}';
    for (final left in [2, 1, 0]) {
      await expectLater(
        receiveProfile(wrong, addresses: loopback, port: port),
        throwsA(
          isA<TransferException>().having(
            (e) => e.message,
            'message',
            left > 0 ? contains('Te quedan $left') : contains('ya no sirve'),
          ),
        ),
      );
    }
    expect(s.current.stage, SendStage.failed);
    // Not even the right code works now.
    await expectLater(
      receiveProfile(s.code.text, addresses: loopback, port: port),
      throwsA(isA<TransferException>()),
    );
  });

  group('Profiles travel with their data', () {
    late AppDatabase dbA, dbB;
    late ProviderContainer a, b;
    setUp(() {
      dbA = AppDatabase(NativeDatabase.memory());
      dbB = AppDatabase(NativeDatabase.memory());
      a = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(dbA)],
      );
      b = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(dbB)],
      );
    });
    tearDown(() async {
      a.dispose();
      b.dispose();
      await dbA.close();
      await dbB.close();
    });

    test('Over the network, then again as replace or copy', () async {
      // Device A: the first profile has a build.
      await a.read(profilesProvider.future);
      await a
          .read(buildRepositoryProvider)
          .save(GenshinBuild(id: 'x', characterId: 'character:10000021'));
      final package = await a
          .read(profilesProvider.notifier)
          .exportPackage(defaultProfileId);

      final s = await sender(encodePackage(package));
      final bytes = await receiveProfile(
        s.code.text,
        addresses: loopback,
        port: port,
      );
      final received = decodePackage(bytes);

      // Device B has its own first profile; the new one comes in beside it.
      final profilesB = b.read(profilesProvider.notifier);
      await b.read(profilesProvider.future);
      expect(await profilesB.sameProfile(received), isNull);
      final imported = await profilesB.importPackage(received);
      expect(imported.name, 'Viajero (copia)');
      final repoB = BuildRepository(
        ScenarioRepository(dbB, prefix: profilePrefix(imported.id)),
      );
      expect((await repoB.loadAll()).single.id, 'x');
      // B's own profile is untouched.
      expect(await BuildRepository(ScenarioRepository(dbB)).loadAll(), isEmpty);

      // The second time it is recognised.
      final same = await profilesB.sameProfile(received);
      expect(same?.id, imported.id);
      await profilesB.importPackage(received, replace: same);
      expect((await b.read(profilesProvider.future)).items, hasLength(2));
      final copy = await profilesB.importPackage(received);
      expect(copy.transferId, isNull);
      expect((await b.read(profilesProvider.future)).items, hasLength(3));
    });

    test('A device holds at most 5 profiles', () async {
      final profiles = a.read(profilesProvider.notifier);
      await a.read(profilesProvider.future);
      for (var i = 2; i <= ProfilesController.maxProfiles; i++) {
        await profiles.save(Profile(id: 'p$i', name: 'P$i'));
      }
      await expectLater(
        profiles.save(const Profile(id: 'p6', name: 'P6')),
        throwsA(isA<ProfileLimitException>()),
      );
      final package = await profiles.exportPackage('p2');
      await expectLater(
        profiles.importPackage(package),
        throwsA(isA<ProfileLimitException>()),
      );
      // Editing one is still allowed, and keeps its transfer id.
      final before = (await a.read(profilesProvider.future)).items[1];
      await profiles.save(const Profile(id: 'p2', name: 'Nuevo nombre'));
      final after = (await a.read(profilesProvider.future)).items[1];
      expect(after.name, 'Nuevo nombre');
      expect(after.transferId, before.transferId);
      expect(after.transferId, isNotNull);
    });
  });
}
