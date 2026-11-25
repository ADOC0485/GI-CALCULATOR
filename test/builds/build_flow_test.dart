import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/builds/domain/build_step.dart';
import 'package:genshin_progress_planner/features/builds/domain/resin_planner.dart';
import 'package:genshin_progress_planner/features/builds/presentation/build_editor_dialog.dart';
import 'package:genshin_progress_planner/features/builds/presentation/build_page.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_provider.dart';
import 'package:genshin_progress_planner/features/progression/domain/inventory_plan.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';
import 'package:genshin_progress_planner/features/progression/presentation/progression_dialog.dart';

void main() {
  final bundle = CatalogBundle.parse(
    File('assets/catalog/seed-v1.json').readAsStringSync(),
  );
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  final amber = bundle.records.firstWhere((r) => r.name == 'Amber');
  const start = ProgressionState(level: 1, ascension: 0);
  const forty = ProgressionState(level: 40, ascension: 1);

  GenshinBuild amberTo(String id, ProgressionState goal) => GenshinBuild(
    id: id,
    characterId: amber.id,
    characterGoal: goal,
    talentsOn: false,
  );

  // Exactly what Amber needs from 1 to 40/40, plus plenty of Mora.
  final cost = calculateProgression(bundle, amber, rules, start, forty);
  final enough = Inventory(
    materials: {
      for (final e in cost.materials.entries)
        if (e.key != 'material:202') e.key: e.value,
    },
    characterBooks: [(cost.experience + 19999) ~/ 20000, 0, 0],
    mora: 10000000,
  );

  test('The build on top reserves the materials first', () {
    final first = amberTo(
      'b1',
      const ProgressionState(level: 90, ascension: 6),
    );
    final second = amberTo('b2', forty);
    final reserved = reserveInventory(
      bundle: bundle,
      rules: rules,
      builds: [first, second],
      inventory: enough,
    );
    final someMaterial = cost.materials.keys.firstWhere(
      (id) => id != 'material:202',
    );
    expect(reserved.holders(someMaterial).first.$1, 'b1');

    // With everything free, the top build can reach 40/40, not further.
    final suggested = suggestStep(
      bundle: bundle,
      rules: rules,
      build: first,
      pool: InventoryPool(enough),
    );
    expect(suggested.character!.level, 40);
    expect(suggested.character!.ascension, 1);

    // The second build gets nothing free: the first one holds it all.
    final none = suggestStep(
      bundle: bundle,
      rules: rules,
      build: second,
      pool: reserved.freeBefore['b2']!,
    );
    expect(none.character!.level, 1);

    // Leveling the second one anyway takes what the first reserved.
    final check = checkStep(
      bundle: bundle,
      rules: rules,
      build: second,
      target: const StepTarget(character: forty),
      inventory: enough,
      builds: [first, second],
    );
    expect(check.short, isEmpty);
    expect(check.takenFrom.keys, ['b1']);
    expect(check.used[someMaterial], cost.materials[someMaterial]);

    // The top one takes nothing reserved by others.
    final own = checkStep(
      bundle: bundle,
      rules: rules,
      build: first,
      target: const StepTarget(character: forty),
      inventory: enough,
      builds: [first, second],
    );
    expect(own.takenFrom, isEmpty);
  });

  test('A build knows its kind and when it reached the goal', () {
    final weapon = GenshinBuild(id: 'w', weaponId: 'weapon:15401');
    expect(weapon.kind, BuildKind.weapon);
    expect(weapon.atGoal, isFalse);
    expect(
      weapon
          .copyWith(weaponNow: const ProgressionState(level: 90, ascension: 6))
          .atGoal,
      isTrue,
    );
    final json = GenshinBuild.fromJson(
      weapon.copyWith(finishedAt: DateTime(2026, 11, 25)).toJson(),
    );
    expect(json.characterId, isNull);
    expect(json.finishedAt, DateTime(2026, 11, 25));
    expect(amberTo('a', forty).kind, BuildKind.character);
  });

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
        progressionRulesProvider.overrideWith((ref) async => rules),
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

  testWidgets('Limit of builds in progress, priority and finished ones', (
    tester,
  ) async {
    final container = await mount(tester, const SizedBox());
    final repo = container.read(buildRepositoryProvider);
    for (var i = 1; i <= 4; i++) {
      await repo.save(amberTo('b$i', forty));
    }
    await expectLater(
      repo.save(amberTo('b5', forty)),
      throwsA(isA<BuildLimitException>()),
    );
    await repo.setActiveLimit(5);
    await repo.save(amberTo('b5', forty));

    await repo.move('b3', up: true);
    expect((await repo.loadAll()).map((b) => b.id), [
      'b1',
      'b3',
      'b2',
      'b4',
      'b5',
    ]);

    // A finished build leaves Inicio and frees a place.
    await repo.save(
      amberTo(
        'b1',
        forty,
      ).copyWith(characterNow: forty, finishedAt: DateTime(2026, 11, 25)),
    );
    final active = await container.read(buildsProvider.future);
    expect(active.map((b) => b.id), ['b3', 'b2', 'b4', 'b5']);
    final finished = await container.read(finishedBuildsProvider.future);
    expect(finished.single.id, 'b1');
    await repo.save(amberTo('b6', forty));
  });

  testWidgets('A weapon-only build is saved without a character', (
    tester,
  ) async {
    final container = await mount(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => BuildEditorDialog(bundle: bundle),
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kind-weapon')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Busca el arma'),
      'Arco de Favonius',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar build'));
    await tester.pumpAndSettle();
    final saved =
        (await container.read(buildRepositoryProvider).loadAll()).single;
    expect(saved.kind, BuildKind.weapon);
    expect(saved.characterId, isNull);
    expect(saved.weaponId, 'weapon:15401');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Subir takes the cost out of the inventory', (tester) async {
    final container = await mount(tester, const SizedBox());
    final repo = container.read(buildRepositoryProvider);
    await repo.save(
      amberTo('a', const ProgressionState(level: 90, ascension: 6)),
    );
    await repo.setOwned({
      ...enough.materials,
      characterExpItems.first.id: enough.characterBooks.first,
      'material:202': enough.mora,
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: BuildPage(buildId: 'a')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-up')));
    await tester.pumpAndSettle();
    // It suggests the most the inventory allows.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('level-up-character')))
          .controller!
          .text,
      '40',
    );
    await tester.tap(find.byKey(const ValueKey('level-up-confirm')));
    await tester.pumpAndSettle();

    final build = (await repo.loadAll()).single;
    expect(build.characterNow.level, 40);
    expect(build.characterNow.ascension, 1);
    expect(build.finished, isFalse);
    final inventory = await repo.inventory();
    for (final id in enough.materials.keys) {
      expect(inventory.owned(id), 0, reason: id);
    }
    expect(inventory.mora, lessThan(enough.mora));
    expect(find.text('Listo: se descontó del inventario.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
