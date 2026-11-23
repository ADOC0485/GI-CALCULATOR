import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';

final scenarioRepositoryProvider = Provider(
  (ref) => ScenarioRepository(ref.watch(databaseProvider)),
);

class ScenarioRepository {
  ScenarioRepository(this.database);
  final AppDatabase database;
  Future<Map<String, dynamic>?> load(String id) async {
    final row = await (database.select(
      database.calculatorScenarios,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.payload) as Map<String, dynamic>;
  }

  Future<void> save(String id, Map<String, dynamic> values) => database
      .into(database.calculatorScenarios)
      .insertOnConflictUpdate(
        CalculatorScenario(id: id, payload: jsonEncode(values)),
      );
}
