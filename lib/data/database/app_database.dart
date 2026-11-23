import 'package:drift/drift.dart';
part 'app_database.g.dart';

class CalculatorScenarios extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

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

class CatalogVersions extends Table {
  TextColumn get version => text()();
  IntColumn get sequence => integer().unique()();
  TextColumn get payload => text()();
  TextColumn get importedAt => text()();
  @override
  Set<Column<Object>> get primaryKey => {version};
}

class CatalogRecords extends Table {
  TextColumn get catalogVersion =>
      text().references(CatalogVersions, #version)();
  TextColumn get recordId => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  @override
  Set<Column<Object>> get primaryKey => {catalogVersion, recordId};
}

class CatalogSelection extends Table {
  // Drift evaluates this reference in the generated table subclass.
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();
  TextColumn get catalogVersion =>
      text().references(CatalogVersions, #version)();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    PreferenceEntries,
    CatalogVersions,
    CatalogRecords,
    CatalogSelection,
    CalculatorScenarios,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if ((from != 1 && from != 2) || to != 3) {
        throw StateError('No existe una migración de $from a $to.');
      }
      await transaction(() async {
        if (from == 1) {
          await migrator.createTable(catalogVersions);
          await migrator.createTable(catalogRecords);
          await migrator.createTable(catalogSelection);
        }
        await migrator.createTable(calculatorScenarios);
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
