import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';

/// Id of the first profile; its data keeps the original keys (no prefix).
const defaultProfileId = 'default';

String profilePrefix(String profileId) =>
    profileId == defaultProfileId ? '' : 'p:$profileId:';

/// Profile whose data the app is showing; the profiles feature sets it.
final activeProfileIdProvider = NotifierProvider<ActiveProfileId, String>(
  ActiveProfileId.new,
);

class ActiveProfileId extends Notifier<String> {
  @override
  String build() => defaultProfileId;
  void select(String id) => state = id;
}

/// Saved data of the active profile (builds, inventory, resin, scenarios…).
final scenarioRepositoryProvider = Provider(
  (ref) => ScenarioRepository(
    ref.watch(databaseProvider),
    prefix: profilePrefix(ref.watch(activeProfileIdProvider)),
  ),
);

/// Data shared by every profile, such as the list of profiles itself.
final sharedScenarioRepositoryProvider = Provider(
  (ref) => ScenarioRepository(ref.watch(databaseProvider)),
);

class ScenarioRepository {
  ScenarioRepository(this.database, {this.prefix = ''});
  final AppDatabase database;

  /// Prepended to every key, so each profile has its own data.
  final String prefix;

  Future<Map<String, dynamic>?> load(String id) async {
    final row = await (database.select(
      database.calculatorScenarios,
    )..where((t) => t.id.equals('$prefix$id'))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.payload) as Map<String, dynamic>;
  }

  Future<void> save(String id, Map<String, dynamic> values) => database
      .into(database.calculatorScenarios)
      .insertOnConflictUpdate(
        CalculatorScenario(id: '$prefix$id', payload: jsonEncode(values)),
      );

  /// Deletes everything saved for [profileId]. For the first profile that is
  /// every key without a profile prefix, except the ones in [keep].
  Future<void> deleteProfileData(String profileId, {Set<String> keep = const {}}) {
    final table = database.calculatorScenarios;
    final query = database.delete(table);
    if (profileId == defaultProfileId) {
      query.where((t) => t.id.like('p:%').not() & t.id.isNotIn(keep));
    } else {
      query.where((t) => t.id.like('${profilePrefix(profileId)}%'));
    }
    return query.go();
  }
}
