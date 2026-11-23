import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/builds/presentation/build_editor_dialog.dart';
import 'package:genshin_progress_planner/features/builds/presentation/build_page.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_provider.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';
import 'package:genshin_progress_planner/features/progression/presentation/progression_dialog.dart';

void main() {
  final bundle = CatalogBundle.parse(
    File('assets/catalog/seed-v1.json').readAsStringSync(),
  );

  Future<ProviderContainer> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        catalogProvider.overrideWith((ref) async => bundle),
        progressionRulesProvider.overrideWith(
          (ref) async => ProgressionRules(
            File('assets/rules/progression-v1.json').readAsStringSync(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Create a build with character and weapon, then plan it', (
    tester,
  ) async {
    final container = await mount(
      tester,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BuildEditorDialog(bundle: bundle),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    // The weapon stays locked until there is a character.
    expect(find.text('Elige primero el personaje'), findsOneWidget);
    // Typing the full name selects it, even without tapping the suggestion.
    await tester.enterText(find.byType(TextField).first, 'amber');
    await tester.pumpAndSettle();
    expect(find.text('Elige primero el personaje'), findsNothing);
    // Only bows are offered for Amber.
    await tester.enterText(
      find.widgetWithText(TextField, 'Busca un arco'),
      '',
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Arco de Favonius'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Espada del Alba'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Arco de Favonius'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar build'));
    await tester.pumpAndSettle();
    final builds = await container.read(buildRepositoryProvider).loadAll();
    expect(builds, hasLength(1));
    expect(builds.single.weaponId, 'weapon:15401');
    expect(builds.single.characterGoal.level, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Build page shows progress, resin plan and inventory', (
    tester,
  ) async {
    final container = await mount(tester, const SizedBox());
    final repo = container.read(buildRepositoryProvider);
    final amber = bundle.records.firstWhere((r) => r.name == 'Amber');
    // Amber 1 → 90 with the Favonius bow.
    await repo.save(
      GenshinBuild(
        id: 'test',
        characterId: amber.id,
        weaponId: 'weapon:15401',
        characterNow: const ProgressionState(level: 1, ascension: 0),
        characterGoal: const ProgressionState(
          level: 90,
          ascension: 6,
          talents: [1, 9, 9],
        ),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: BuildPage(buildId: 'test')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu avance'), findsOneWidget);
    expect(find.text('Plan de resina'), findsOneWidget);
    expect(find.textContaining('Hoy ·'), findsOneWidget);
    expect(find.textContaining('A este ritmo terminas'), findsOneWidget);
    expect(find.text('Tu inventario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
