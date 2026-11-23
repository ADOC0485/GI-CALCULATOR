import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/profiles/profile.dart';
import 'package:genshin_progress_planner/features/progression/data/scenario_repository.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  GenshinBuild build(String id) => GenshinBuild(
    id: id,
    characterId: 'character:10000021',
    characterNow: const ProgressionState(level: 1, ascension: 0),
    characterGoal: const ProgressionState(level: 90, ascension: 6),
  );

  test('Greeting follows the chosen gender', () {
    expect(const Profile(id: 'a', name: 'Ana', gender: 'Femenino').greeting,
        '¡Bienvenida, Ana!');
    expect(const Profile(id: 'a', name: 'Leo', gender: 'Masculino').greeting,
        '¡Bienvenido, Leo!');
    expect(const Profile(id: 'a', name: 'Kai').greeting, '¡Hola, Kai!');
  });

  test('Existing data becomes the first profile', () async {
    // Data saved before profiles existed (no prefix).
    await ScenarioRepository(db).save('inventario', {'worldLevel': '7', 'adventureRank': '52'});
    await BuildRepository(ScenarioRepository(db)).save(build('old'));
    final profiles = await container.read(profilesProvider.future);
    expect(profiles.items.single.id, defaultProfileId);
    expect(profiles.active.worldLevel, 7);
    expect(profiles.active.adventureRank, 52);
    final builds = await container.read(buildRepositoryProvider).loadAll();
    expect(builds.single.id, 'old');
  });

  test('Each profile has its own data, and deleting one erases it', () async {
    await container.read(profilesProvider.future);
    await container.read(buildRepositoryProvider).save(build('main'));
    final notifier = container.read(profilesProvider.notifier);
    await notifier.save(
      const Profile(id: 'alt', name: 'Alt', server: 'Europa', worldLevel: 5, adventureRank: 40),
      activate: true,
    );
    expect(container.read(activeProfileIdProvider), 'alt');
    final alt = container.read(buildRepositoryProvider);
    expect(await alt.loadAll(), isEmpty);
    expect((await alt.inventory()).worldLevel, 5);
    await alt.save(build('second'));

    await notifier.activate(defaultProfileId);
    final main = container.read(buildRepositoryProvider);
    expect((await main.loadAll()).map((b) => b.id), ['main']);

    await notifier.delete('alt');
    final left = await container.read(profilesProvider.future);
    expect(left.items.map((p) => p.id), [defaultProfileId]);
    final orphan = BuildRepository(ScenarioRepository(db, prefix: profilePrefix('alt')));
    expect(await orphan.loadAll(), isEmpty);
    // The profile in use cannot be deleted.
    await notifier.delete(defaultProfileId);
    expect((await container.read(profilesProvider.future)).items, hasLength(1));
  });
}
