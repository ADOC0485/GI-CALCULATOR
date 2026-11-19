import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/features/settings/data/drift_preferences_repository.dart';
import 'package:genshin_progress_planner/features/settings/domain/app_preferences.dart';

void main() {
  test('Fresh schema uses pastel light appearance without fake data', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      (await DriftPreferencesRepository(db).load()).appearance,
      AppAppearance.light,
    );
    expect(await db.select(db.preferenceEntries).get(), isEmpty);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 1);
  });

  test(
    'Preference persists after closing and reopening a real SQLite file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gi_preferences_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/preferences.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      try {
        final repository = DriftPreferencesRepository(first);
        await repository.save(
          const AppPreferences(appearance: AppAppearance.light),
        );
        await repository.save(
          const AppPreferences(appearance: AppAppearance.system),
        );
        expect(await first.select(first.preferenceEntries).get(), hasLength(1));
      } finally {
        await first.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(
        (await DriftPreferencesRepository(reopened).load()).appearance,
        AppAppearance.system,
      );
    },
  );

  test('Schema rejects invalid themes and multiple singleton rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = DriftPreferencesRepository(db);
    await repository.save(
      const AppPreferences(appearance: AppAppearance.light),
    );
    await expectLater(
      db.customStatement(
        "UPDATE preference_entries SET appearance = 'invalid'",
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO preference_entries (id, appearance) VALUES (2, 'dark')",
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repository.load()).appearance, AppAppearance.light);
  });

  test(
    'Corrupt file fails without silently deleting or resetting it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gi_corrupt_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/broken.sqlite');
      final content = List<int>.filled(4096, 42);
      await file.writeAsBytes(content);
      final db = AppDatabase(NativeDatabase(file));
      try {
        await expectLater(
          DriftPreferencesRepository(db).load(),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
      expect(await file.readAsBytes(), content);
    },
  );
}
