import 'package:genshin_progress_planner/features/settings/domain/app_preferences.dart';
import 'package:genshin_progress_planner/features/settings/domain/preferences_repository.dart';

// Test double only: no demonstration game data is used by the application.
class MemoryPreferencesRepository implements PreferencesRepository {
  AppPreferences preferences = const AppPreferences();
  bool failLoad = false;
  bool failSave = false;

  @override
  Future<AppPreferences> load() async {
    if (failLoad) throw StateError('Simulated storage read failure');
    return preferences;
  }

  @override
  Future<void> save(AppPreferences value) async {
    if (failSave) throw StateError('Simulated storage write failure');
    preferences = value;
  }
}
