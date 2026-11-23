import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';

class DriftCatalogRepository implements CatalogRepository {
  DriftCatalogRepository(this.database);
  final AppDatabase database;

  @override
  Future<CatalogBundle?> loadActive() async {
    final row = await database
        .select(database.catalogSelection)
        .getSingleOrNull();
    return row == null ? null : loadVersion(row.catalogVersion);
  }

  @override
  Future<CatalogBundle?> loadVersion(String version) async {
    final row = await (database.select(
      database.catalogVersions,
    )..where((t) => t.version.equals(version))).getSingleOrNull();
    return row == null ? null : CatalogBundle.parse(row.payload);
  }

  @override
  Future<CatalogImportResult> importCatalog(CatalogBundle bundle) =>
      database.transaction(() async {
        final existing = await loadVersion(bundle.version);
        if (existing != null &&
            existing.canonicalJson != bundle.canonicalJson) {
          throw const CatalogValidationException(
            'Una versión existente no puede cambiar de contenido.',
          );
        }
        final current = await loadActive();
        if (current?.version == bundle.version) {
          return CatalogImportResult(
            changed: false,
            version: bundle.version,
            recordCount: bundle.records.length,
          );
        }
        if (current != null && bundle.sequence <= current.sequence) {
          throw const CatalogValidationException(
            'La secuencia debe ser posterior a la versión activa.',
          );
        }
        if (existing == null) {
          await database
              .into(database.catalogVersions)
              .insert(
                CatalogVersionsCompanion.insert(
                  version: bundle.version,
                  sequence: bundle.sequence,
                  payload: bundle.canonicalJson,
                  importedAt: DateTime.now().toUtc().toIso8601String(),
                ),
              );
          await database.batch(
            (batch) => batch.insertAll(database.catalogRecords, [
              for (final record in bundle.records)
                CatalogRecordsCompanion.insert(
                  catalogVersion: bundle.version,
                  recordId: record.id,
                  kind: record.kind.name,
                  name: record.name,
                ),
            ]),
          );
        }
        await database
            .into(database.catalogSelection)
            .insertOnConflictUpdate(
              CatalogSelectionCompanion.insert(
                id: const Value(1),
                catalogVersion: bundle.version,
              ),
            );
        return CatalogImportResult(
          changed: true,
          version: bundle.version,
          recordCount: bundle.records.length,
        );
      });
}
