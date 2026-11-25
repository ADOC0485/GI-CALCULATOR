import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/app/app_router.dart';
import 'package:genshin_progress_planner/app/navigation.dart';
import 'package:genshin_progress_planner/app/planner_app.dart';
import 'package:genshin_progress_planner/features/settings/domain/app_preferences.dart';
import 'package:genshin_progress_planner/features/settings/presentation/preferences_controller.dart';

import 'support/memory_preferences_repository.dart';

import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/profiles/profile.dart';
import 'package:genshin_progress_planner/features/updates/app_update.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_provider.dart';

Future<ProviderContainer> mountApp(
  WidgetTester tester,
  MemoryPreferencesRepository repository, {
  Size size = const Size(1280, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final container = ProviderContainer(
    retry: (count, error) => null,
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repository),
      buildsProvider.overrideWith((ref) async => []),
      profilesProvider.overrideWith(_FixedProfiles.new),
      latestReleaseProvider.overrideWith((ref) async => null),
      inventoryProvider.overrideWith((ref) async => const Inventory()),
      historyProvider.overrideWith((ref) async => []),
      buildRepositoryProvider.overrideWithValue(_MemoryBuilds()),
      catalogProvider.overrideWith(
        (ref) async => CatalogBundle.parse(
          File('assets/catalog/seed-v1.json').readAsStringSync(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const PlannerApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('All eight navigation destinations are reachable', (
    tester,
  ) async {
    await mountApp(tester, MemoryPreferencesRepository());
    expect(find.text('¡Hola, Viajero!'), findsOneWidget);
    for (final section in AppSection.values.skip(1)) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(section.label),
        ),
      );
      await tester.pumpAndSettle();
      if (section == AppSection.settings) {
        expect(find.text('Apariencia'), findsOneWidget);
      } else if (section == AppSection.characters ||
          section == AppSection.weapons) {
        expect(find.textContaining('Catálogo inicial'), findsOneWidget);
      } else if (section == AppSection.wishes) {
        expect(find.text('Calculadora de deseos'), findsOneWidget);
      } else if (section == AppSection.agenda) {
        expect(find.textContaining('Aún no tienes builds'), findsOneWidget);
      } else if (section == AppSection.inventory) {
        expect(find.text('EXP y Mora'), findsOneWidget);
      } else if (section == AppSection.history) {
        expect(find.textContaining('Todavía no hay nada'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Theme changes only after saving successfully', (tester) async {
    final repository = MemoryPreferencesRepository();
    final container = await mountApp(tester, repository);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Ajustes'),
      ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    expect(repository.preferences.appearance, AppAppearance.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Viajero!'), findsOneWidget);
  });

  testWidgets('Corner button toggles dark and light mode', (tester) async {
    final repository = MemoryPreferencesRepository();
    await mountApp(tester, repository);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(repository.preferences.appearance, AppAppearance.dark);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(repository.preferences.appearance, AppAppearance.light);
  });

  testWidgets('Failed save is visible and keeps previous appearance', (
    tester,
  ) async {
    final repository = MemoryPreferencesRepository()..failSave = true;
    await mountApp(tester, repository);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Ajustes'),
      ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo guardar.'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    repository.failSave = false;
    await tester.ensureVisible(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();
    expect(repository.preferences.appearance, AppAppearance.dark);
  });

  testWidgets('Startup failure offers retry and recovers', (tester) async {
    final repository = MemoryPreferencesRepository()..failLoad = true;
    await mountApp(tester, repository);
    expect(find.text('No pudimos abrir tus preferencias.'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Viajero!'), findsOneWidget);
  });

  for (final width in [360.0, 480.0, 800.0, 1280.0]) {
    testWidgets('Resizable layout at width $width has no overflow', (
      tester,
    ) async {
      await mountApp(
        tester,
        MemoryPreferencesRepository(),
        size: Size(width, 720),
      );
      expect(tester.takeException(), isNull);
      if (width < 680) {
        await tester.tap(find.byTooltip('Abrir el menú de navegación'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Ajustes'));
      } else {
        await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Ajustes'),
      ));
      }
      await tester.pumpAndSettle();
      expect(find.text('Apariencia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Unknown route provides a working return to dashboard', (
    tester,
  ) async {
    final container = await mountApp(tester, MemoryPreferencesRepository());
    container.read(routerProvider).go('/missing');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Página no encontrada · Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, Viajero!'), findsOneWidget);
  });

  testWidgets('Large text remains usable', (tester) async {
    await mountApp(tester, MemoryPreferencesRepository(), textScale: 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('System appearance follows operating system brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final repository = MemoryPreferencesRepository()
      ..preferences = const AppPreferences(appearance: AppAppearance.system);
    await mountApp(tester, repository);
    final heading = find.text('¡Hola, Viajero!');
    expect(Theme.of(tester.element(heading)).brightness, Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(heading)).brightness, Brightness.light);
  });
}

/// Build repository without a database, for app-level tests.
class _MemoryBuilds implements BuildRepository {
  final _store = <String, Map<String, dynamic>>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>> rawInventory() async =>
      _store['inventario'] ?? {'schema': 1};
  @override
  Future<Inventory> inventory() async => Inventory.fromJson(await rawInventory());
  @override
  Future<void> updateInventory(Map<String, Object?> changes) async =>
      _store['inventario'] = {...await rawInventory(), ...changes};
  @override
  Future<void> log(String text) async {}
  @override
  Future<List<GenshinBuild>> loadAll() async => [];
  @override
  Future<int> activeLimit() async => BuildRepository.defaultLimit;
  @override
  Future<List<HistoryEntry>> history() async => [];
  @override
  Future<Set<String>> checked(String buildId, DateTime day) async => {};
}

class _FixedProfiles extends ProfilesController {
  @override
  Future<Profiles> build() async =>
      const Profiles([Profile(id: 'default', name: 'Viajero')], 'default');
}
