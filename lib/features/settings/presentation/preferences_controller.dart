import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database_connection.dart';
import '../data/drift_preferences_repository.dart';
import '../domain/app_preferences.dart';
import '../domain/preferences_repository.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  final database = openAppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return DriftPreferencesRepository(database);
});

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(
      PreferencesController.new,
      retry: (count, error) => null,
    );

class PreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() =>
      ref.watch(preferencesRepositoryProvider).load();

  Future<void> setAppearance(AppAppearance appearance) async {
    final preferences = AppPreferences(appearance: appearance);
    await ref.read(preferencesRepositoryProvider).save(preferences);
    if (ref.mounted) state = AsyncData(preferences);
  }
}
