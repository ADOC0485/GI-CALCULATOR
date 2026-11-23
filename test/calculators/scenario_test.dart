import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/features/progression/data/scenario_repository.dart';

void main() {
  test('Migration 2–3 keeps catalog and preferences, adds scenarios', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            "CREATE TABLE preference_entries (id INTEGER NOT NULL PRIMARY KEY CHECK(id=1), appearance TEXT NOT NULL)",
          );
          raw.execute("INSERT INTO preference_entries VALUES (1,'dark')");
          raw.execute(
            'CREATE TABLE catalog_versions (version TEXT NOT NULL PRIMARY KEY, sequence INTEGER NOT NULL UNIQUE, payload TEXT NOT NULL, imported_at TEXT NOT NULL)',
          );
          raw.execute(
            'CREATE TABLE catalog_records (catalog_version TEXT NOT NULL REFERENCES catalog_versions(version), record_id TEXT NOT NULL, kind TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (catalog_version, record_id))',
          );
          raw.execute(
            'CREATE TABLE catalog_selection (id INTEGER NOT NULL PRIMARY KEY CHECK(id=1), catalog_version TEXT NOT NULL REFERENCES catalog_versions(version))',
          );
          raw.execute(
            "INSERT INTO catalog_versions VALUES ('test',1,'{}','2026-11-19')",
          );
          raw.execute("INSERT INTO catalog_selection VALUES (1,'test')");
          raw.execute('PRAGMA user_version=2');
        },
      ),
    );
    addTearDown(db.close);
    final repo = ScenarioRepository(db);
    await repo.save('wishes', {'schema': 1, 'primogems': 8000});
    expect((await repo.load('wishes'))!['primogems'], 8000);
    expect(
      (await db.select(db.preferenceEntries).getSingle()).appearance,
      'dark',
    );
    expect(
      (await db.select(db.catalogSelection).getSingle()).catalogVersion,
      'test',
    );
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      3,
    );
  });
  test('Scenarios survive reopening, remain independent and failed writes rollback', () async {
    final directory = await Directory.systemTemp.createTemp('gi_scenarios_');
    final file = File('${directory.path}/test.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    try {
      final repo = ScenarioRepository(first);
      await repo.save('wishes', {'primogems': 8000});
      await repo.save('progression:amber', {'level': 80});
      await first.customStatement(
        "CREATE TRIGGER fail_update BEFORE UPDATE ON calculator_scenarios BEGIN SELECT RAISE(ABORT,'test failure'); END",
      );
      await expectLater(
        repo.save('wishes', {'primogems': 0}),
        throwsA(isA<Exception>()),
      );
    } finally {
      await first.close();
    }
    final second = AppDatabase(NativeDatabase(file));
    try {
      final repo = ScenarioRepository(second);
      expect(await repo.load('wishes'), {'primogems': 8000});
      expect(await repo.load('progression:amber'), {'level': 80});
      expect(await repo.load('missing'), isNull);
    } finally {
      await second.close();
      await directory.delete(recursive: true);
    }
  });
}
