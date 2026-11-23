import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:genshin_progress_planner/app/planner_app.dart';
import 'package:genshin_progress_planner/data/database/database_connection.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/catalog/data/drift_catalog_repository.dart';
import 'package:genshin_progress_planner/features/settings/data/drift_preferences_repository.dart';
import 'package:genshin_progress_planner/features/settings/domain/app_preferences.dart';
import 'package:genshin_progress_planner/features/settings/presentation/preferences_controller.dart';
import 'package:genshin_progress_planner/features/progression/data/scenario_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows native storage survives an application restart', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    expect(support.isAbsolute, isTrue);
    final directory = await Directory.systemTemp.createTemp(
      'gi_native_integration_',
    );
    final path = '${directory.path}/preferences.sqlite';
    final firstDb = openAppDatabase(databasePath: () async => path);
    final firstRepo = DriftPreferencesRepository(firstDb);
    final firstContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(firstDb),
        preferencesRepositoryProvider.overrideWithValue(firstRepo),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: firstContainer,
          child: const PlannerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Personajes'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amber'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Deseos'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Protogemas'),
        '8000',
      );
      await tester.scrollUntilVisible(
        find.text('Guardar escenario'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Guardar escenario'));
      await tester.pumpAndSettle();
      expect(
        (await ScenarioRepository(firstDb)
            .load('wishes'))!['fields']['Protogemas'],
        '8000',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Inicio'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Ajustes'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      expect((await firstRepo.load()).appearance, AppAppearance.dark);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      firstContainer.dispose();
      await firstDb.close();
    }
    final secondDb = openAppDatabase(databasePath: () async => path);
    final secondContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(secondDb),
        preferencesRepositoryProvider.overrideWithValue(
          DriftPreferencesRepository(secondDb),
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: secondContainer,
          child: const PlannerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tu próxima aventura'), findsOneWidget);
      expect(
        (await ScenarioRepository(secondDb)
            .load('wishes'))!['fields']['Protogemas'],
        '8000',
      );
      expect(
        (await DriftCatalogRepository(secondDb).loadActive())!.records.length,
        92,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      secondContainer.dispose();
      await secondDb.close();
      await directory.delete(recursive: true);
    }
  });
}
