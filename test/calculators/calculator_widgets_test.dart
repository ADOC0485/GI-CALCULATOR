import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart'
    hide CatalogRecord;
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/wishes/presentation/wishes_page.dart';
import 'package:genshin_progress_planner/features/progression/presentation/progression_dialog.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 1100,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          calculationClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 23, 12),
          ),
          progressionRulesProvider.overrideWith(
            (ref) async => ProgressionRules(
              File('assets/rules/progression-v1.json').readAsStringSync(),
            ),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder input(String label) => find.widgetWithText(TextField, label);
  testWidgets(
    'Wish inputs recompute and saved scenario restores exact inputs',
    (tester) async {
      await mount(tester, const WishesPage());
      await tester.enterText(input('Protogemas'), '8000');
      await tester.scrollUntilVisible(
        input('Días hasta el objetivo'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('Días hasta el objetivo'), '15');
      await tester.scrollUntilVisible(
        input('Días restantes de Bendición'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('Días restantes de Bendición'), '25');
      await tester.scrollUntilVisible(
        find.text('64 deseos previstos'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('10 protogemas sobrantes').first,
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Guardar escenario'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar escenario'));
      await tester.pumpAndSettle();
      expect(find.text('Escenario guardado en este equipo.'), findsOneWidget);
      await tester.scrollUntilVisible(
        input('Protogemas'),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('Protogemas'), '0');
      await tester.scrollUntilVisible(
        find.text('Recuperar escenario'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Recuperar escenario'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('64 deseos previstos'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('64 deseos previstos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Invalid fractional input hides projection and disables saving', (
    tester,
  ) async {
    await mount(tester, const WishesPage(), width: 480);
    await tester.enterText(input('Protogemas'), '1.5');
    await tester.scrollUntilVisible(
      find.text('Guardar escenario'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Guardar escenario'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('introduce un entero no negativo'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Progression dialog calculates XP and rejects impossible ascension',
    (tester) async {
      final bundle = CatalogBundle.parse(
        File('assets/catalog/seed-v1.json').readAsStringSync(),
      );
      await mount(
        tester,
        ProgressionDialog(
          bundle: bundle,
          record: bundle.records.firstWhere((r) => r.name == 'Amber'),
        ),
        width: 800,
      );
      await tester.scrollUntilVisible(
        find.text('EXP necesaria: 8 362 650'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('EXP necesaria: 8 362 650'), findsOneWidget);
      // No partial EXP field: the game does not show it.
      expect(find.textContaining('EXP parcial'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('level-actual')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      // 50/50 vs 50/60, like the in-game level display.
      await tester.enterText(find.byKey(const ValueKey('level-actual')), '50');
      await tester.pumpAndSettle();
      expect(find.text('50 · sin ascender'), findsOneWidget);
      expect(find.text('Ascensión 2/6'), findsOneWidget);
      await tester.tap(find.text('50 · sin ascender'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 · ya ascendido').last);
      await tester.pumpAndSettle();
      expect(find.text('Ascensión 3/6'), findsOneWidget);
      // Talents stay hidden until the box is ticked.
      expect(find.text('Ataque normal'), findsNothing);
      await tester.tap(find.text('Subir talentos'));
      await tester.pumpAndSettle();
      expect(find.text('Ataque normal'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('level-objetivo')), '95');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('save-to-build')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Calculator saves into builds and reloads from them', (
    tester,
  ) async {
    final bundle = CatalogBundle.parse(
      File('assets/catalog/seed-v1.json').readAsStringSync(),
    );
    final amber = bundle.records.firstWhere((r) => r.name == 'Amber');
    final bow = bundle.records.firstWhere((r) => r.id == 'weapon:15401');
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        progressionRulesProvider.overrideWith(
          (ref) async => ProgressionRules(
            File('assets/rules/progression-v1.json').readAsStringSync(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    Future<void> open(CatalogRecord record) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ProgressionDialog(bundle: bundle, record: record),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    await open(amber);
    await tester.enterText(find.byKey(const ValueKey('level-actual')), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-to-build')));
    await tester.pumpAndSettle();
    expect(find.text('Build de Amber guardada.'), findsOneWidget);
    final repo = container.read(buildRepositoryProvider);
    final saved = (await repo.loadAll()).single;
    expect(saved.characterId, amber.id);
    expect(saved.characterNow.level, 50);
    expect(saved.characterGoal.level, 90);

    // Reopening the calculator starts from the build.
    await open(amber);
    expect(find.text('Valores cargados de tu build.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('level-actual')))
          .controller!
          .text,
      '50',
    );
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    // A bow gets a build of its own ("Solo arma").
    await open(bow);
    await tester.tap(find.byKey(const ValueKey('save-to-build')));
    await tester.pumpAndSettle();
    final all = await repo.loadAll();
    expect(all, hasLength(2));
    expect(all.first.weaponId, isNull);
    expect(all.last.kind, BuildKind.weapon);
    expect(all.last.characterId, isNull);
    expect(all.last.weaponId, bow.id);
    expect(all.last.weaponGoal.level, 90);
    expect(tester.takeException(), isNull);
  });
}
