import '../../../data/database/app_database.dart';
import '../domain/app_preferences.dart';
import '../domain/preferences_repository.dart';

class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository(this.database);
  final AppDatabase database;
  @override
  Future<AppPreferences> load() async {
    final row = await database
        .select(database.preferenceEntries)
        .getSingleOrNull();
    if (row == null) return const AppPreferences();
    return AppPreferences(
      appearance: AppAppearance.values.byName(row.appearance),
    );
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    await database
        .into(database.preferenceEntries)
        .insertOnConflictUpdate(
          PreferenceEntry(id: 1, appearance: preferences.appearance.name),
        );
  }
}
