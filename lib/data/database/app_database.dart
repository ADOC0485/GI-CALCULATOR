import 'package:drift/drift.dart';
part 'app_database.g.dart';

class PreferenceEntries extends Table {
  // Drift resolves these references to columns in the generated table subclass.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();
  TextColumn get appearance =>
      // ignore: recursive_getters
      text().check(appearance.isIn(['dark', 'light', 'system']))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [PreferenceEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      throw StateError('No existe una migración de $from a $to.');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
