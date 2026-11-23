import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
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
        find.text('EXP necesaria: 8362650'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('EXP necesaria: 8362650'), findsOneWidget);
      await tester.scrollUntilVisible(
        input('Ascensión objetivo'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(input('Ascensión objetivo'), '0');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar escenario'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
