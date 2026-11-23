import 'catalog.dart';

class CatalogImportResult {
  const CatalogImportResult({
    required this.changed,
    required this.version,
    required this.recordCount,
  });
  final bool changed;
  final String version;
  final int recordCount;
}

abstract interface class CatalogRepository {
  Future<CatalogBundle?> loadActive();
  Future<CatalogBundle?> loadVersion(String version);
  Future<CatalogImportResult> importCatalog(CatalogBundle bundle);
}
