import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/catalog/data/drift_catalog_repository.dart';
import 'package:genshin_progress_planner/features/settings/data/drift_preferences_repository.dart';
import 'package:genshin_progress_planner/features/settings/domain/app_preferences.dart';

Map<String, dynamic> seedJson() =>
    jsonDecode(File('assets/catalog/seed-v1.json').readAsStringSync())
        as Map<String, dynamic>;
CatalogBundle bundle([void Function(Map<String, dynamic>)? change]) {
  final json = seedJson();
  change?.call(json);
  return CatalogBundle.parse(jsonEncode(json));
}

void main() {
  test(
    'Real seed has coherent references and source metadata for every record',
    () {
      final catalog = bundle();
      expect(catalog.records.length, 92);
      expect(
        catalog.records
            .where((r) => r.kind == CatalogKind.character)
            .map((r) => r.name)
            .toSet(),
        {'Amber', 'Kaeya', 'Lisa'},
      );
      expect(
        catalog.records.every(
          (r) =>
              r.provenance.revision ==
              '8e5badd60b5d894284ccc927a56c9683529d2592',
        ),
        isTrue,
      );
      final amber = catalog.records.singleWhere(
        (r) => r.id == 'character:10000021',
      );
      expect(
        amber.progression!.requirements.first.materials['material:202'],
        20000,
      );
      expect(amber.canUseFields(['requirements']), isTrue);
      expect(amber.canUseFields(['experience']), isFalse);
      expect(amber.canUseFields(['unknown']), isFalse);
      final domain = catalog.records.singleWhere(
        (r) => r.id == 'activity:domain:4210',
      );
      expect(domain.activity!.days, [1, 4, 7]);
      expect(domain.canUseFields(['resinCost']), isFalse);
    },
  );

  final invalidCases = <String, void Function(Map<String, dynamic>)>{
    'duplicate IDs': (j) => (j['records'] as List).add(j['records'][0]),
    'missing reference': (j) =>
        (j['records'] as List).removeWhere((r) => r['id'] == 'material:202'),
    'negative material count': (j) {
      final c = (j['records'] as List).firstWhere(
        (r) => r['kind'] == 'character',
      );
      c['requirements'][0]['materials']['material:202'] = -1;
    },
    'fractional count': (j) {
      final c = (j['records'] as List).firstWhere(
        (r) => r['kind'] == 'character',
      );
      c['requirements'][0]['materials']['material:202'] = 2.5;
    },
    'invalid calendar': (j) {
      final a = (j['records'] as List).firstWhere(
        (r) => r['kind'] == 'activity',
      );
      a['days'] = [8];
    },
    'unsupported schema': (j) => j['schemaVersion'] = 9,
    'invalid date': (j) => j['createdAt'] = '2026-02-30',
    'missing source': (j) => j['records'][0]['provenance']['source'] = '',
    'missing reliability': (j) =>
        j['records'][0]['provenance']['reliability'] = 'trusted',
    'missing pending label': (j) {
      final c = (j['records'] as List).firstWhere(
        (r) => r['kind'] == 'character',
      );
      c['pendingFields'] = [];
    },
    'duplicate requirement': (j) {
      final c = (j['records'] as List).firstWhere(
        (r) => r['kind'] == 'character',
      );
      (c['requirements'] as List).add(c['requirements'][0]);
    },
    'unverified dependency': (j) {
      final m = (j['records'] as List).firstWhere(
        (r) => r['id'] == 'material:202',
      );
      m['provenance']['reliability'] = 'pending';
    },
  };
  for (final invalid in invalidCases.entries) {
    test('Rejects ${invalid.key}', () {
      expect(
        () => bundle(invalid.value),
        throwsA(isA<CatalogValidationException>()),
      );
    });
  }
  test(
    'Malformed JSON reports a validation error',
    () => expect(
      () => CatalogBundle.parse('{'),
      throwsA(isA<CatalogValidationException>()),
    ),
  );

  test('Unverified records are never eligible for exact calculations', () {
    final catalog = bundle((j) {
      for (final r in j['records']) {
        r['provenance']['reliability'] = 'pending';
      }
    });
    expect(
      catalog.records.every((r) => !r.canUseFields(['requirements'])),
      isTrue,
    );
  });

  test('Import is idempotent and preserves preferences and unrelated user data', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final preferences = DriftPreferencesRepository(db);
    await preferences.save(
      const AppPreferences(appearance: AppAppearance.dark),
    );
    // A stand-in user table proves the importer does not reset unrelated data.
    await db.customStatement(
      'CREATE TABLE user_data_probe (amount INTEGER NOT NULL)',
    );
    await db.customStatement('INSERT INTO user_data_probe VALUES (347)');
    final repository = DriftCatalogRepository(db);
    expect((await repository.importCatalog(bundle())).changed, isTrue);
    expect((await repository.importCatalog(bundle())).changed, isFalse);
    expect(await db.select(db.catalogRecords).get(), hasLength(92));
    expect((await preferences.load()).appearance, AppAppearance.dark);
    expect(
      (await db.customSelect('SELECT amount FROM user_data_probe').getSingle())
          .read<int>('amount'),
      347,
    );
  });

  test(
    'New versions preserve old snapshots and reject collisions and downgrades',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftCatalogRepository(db);
      await repo.importCatalog(bundle());
      await expectLater(
        repo.importCatalog(
          bundle((j) => j['records'][0]['name'] = 'TEST ONLY'),
        ),
        throwsA(isA<CatalogValidationException>()),
      );
      final next = bundle((j) {
        j['version'] = 'test-v2';
        j['sequence'] = 2;
      });
      await repo.importCatalog(next);
      expect((await repo.loadActive())!.version, 'test-v2');
      expect((await repo.loadVersion('2026.11.19.1'))!.records.length, 92);
      await expectLater(
        repo.importCatalog(bundle()),
        throwsA(isA<CatalogValidationException>()),
      );
      expect((await repo.loadActive())!.version, 'test-v2');
    },
  );

  test(
    'Database failure rolls back both records and version activation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftCatalogRepository(db);
      await repo.importCatalog(bundle());
      await db.customStatement(
        "CREATE TRIGGER fail_catalog BEFORE INSERT ON catalog_records WHEN NEW.catalog_version = 'test-v2' BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
      );
      await expectLater(
        repo.importCatalog(
          bundle((j) {
            j['version'] = 'test-v2';
            j['sequence'] = 2;
          }),
        ),
        throwsA(isA<Exception>()),
      );
      expect((await repo.loadActive())!.version, '2026.11.19.1');
      expect(await repo.loadVersion('test-v2'), isNull);
      expect(await db.select(db.catalogRecords).get(), hasLength(92));
    },
  );

  test(
    'Migration from phase 1 preserves the original preference row',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              "CREATE TABLE preference_entries (id INTEGER NOT NULL PRIMARY KEY CHECK(id=1), appearance TEXT NOT NULL CHECK(appearance IN ('dark','light','system')))",
            );
            raw.execute("INSERT INTO preference_entries VALUES (1, 'dark')");
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(db.close);
      expect(
        (await DriftPreferencesRepository(db).load()).appearance,
        AppAppearance.dark,
      );
      await DriftCatalogRepository(db).importCatalog(bundle());
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        2,
      );
      expect(
        (await DriftPreferencesRepository(db).load()).appearance,
        AppAppearance.dark,
      );
    },
  );

  test(
    'Catalog remains available after closing and reopening SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gi_catalog_test_',
      );
      final file = File('${directory.path}/catalog.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      try {
        await DriftCatalogRepository(first).importCatalog(bundle());
      } finally {
        await first.close();
      }
      final second = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await DriftCatalogRepository(second).loadActive())!.records.length,
          92,
        );
      } finally {
        await second.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
