import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_page.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_provider.dart';

void main() {
  testWidgets('Browse real characters, filter and inspect their provenance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bundle = CatalogBundle.parse(
      File('assets/catalog/seed-v1.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogProvider.overrideWith((ref) async => bundle)],
        child: const MaterialApp(
          home: Scaffold(body: CatalogPage(initialKind: CatalogKind.character)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Amber'), findsOneWidget);
    expect(find.text('Lisa'), findsOneWidget);
    // Filter by element and weapon when the name is forgotten.
    await tester.tap(find.widgetWithText(FilterChip, 'Pyro'));
    await tester.pumpAndSettle();
    expect(find.text('Amber'), findsOneWidget);
    expect(find.text('Lisa'), findsNothing);
    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Catalizador'));
    await tester.pumpAndSettle();
    expect(find.text('Lisa'), findsOneWidget);
    expect(find.text('Amber'), findsNothing);
    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Amber'), findsOneWidget);
    // Weapons can be filtered by rarity and type.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Armas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '3 ★'));
    await tester.pumpAndSettle();
    expect(find.text('Espada del Alba'), findsOneWidget);
    expect(find.text('Arco de Favonius'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Personajes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'amber');
    await tester.pumpAndSettle();
    expect(find.text('Lisa'), findsNothing);
    await tester.tap(find.text('Amber'));
    await tester.pumpAndSettle();
    expect(find.text('Ascensión 1'), findsOneWidget);
    expect(find.textContaining('experiencia por nivel'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-a-character');
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay coincidencias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid import cannot be activated', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CatalogImportDialog())),
      ),
    );
    await tester.enterText(find.byType(TextField), '{bad json');
    await tester.tap(find.text('Validar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('JSON mal formado'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Activar catálogo'),
          )
          .onPressed,
      isNull,
    );
  });
}
