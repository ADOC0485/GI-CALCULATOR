import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database_provider.dart';
import '../data/drift_catalog_repository.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => DriftCatalogRepository(ref.watch(databaseProvider)),
);

final catalogProvider = FutureProvider<CatalogBundle>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  final active = await repository.loadActive();
  if (active != null) return active;
  final seed = CatalogBundle.parse(
    await rootBundle.loadString('assets/catalog/seed-v1.json'),
  );
  await repository.importCatalog(seed);
  return (await repository.loadActive())!;
}, retry: (count, error) => null);
