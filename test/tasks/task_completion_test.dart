import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/data/build_repository.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/builds/domain/resin_planner.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/catalog/presentation/catalog_provider.dart';
import 'package:genshin_progress_planner/features/resin/resin_state.dart';
import 'package:genshin_progress_planner/features/resin/wallet.dart';
import 'package:genshin_progress_planner/features/tasks/task_completion.dart';
import 'package:genshin_progress_planner/features/tasks/task_log.dart';

void main() {
  final t0 = DateTime(2026, 11, 24, 10);

  test('Spending resin keeps the progress towards the next point', () {
    final r = ResinState(original: 100, updatedAt: t0, condensed: 2);
    // 20 minutes later: 102 and 4 minutes towards the next point.
    final later = t0.add(const Duration(minutes: 20));
    final spent = r.spend(later, original: 40, condensed: 1);
    expect(spent.originalAt(later), 62);
    expect(spent.condensed, 1);
    expect(spent.nextIn(later), const Duration(minutes: 4));
    // Giving it back restores it.
    final back = spent.spend(later, original: -40, condensed: -1);
    expect(back.originalAt(later), 102);
    expect(back.condensed, 2);
    // Never below zero.
    expect(r.spend(t0, original: 500).originalAt(t0), 0);
  });

  test('A weekly boss already claimed this week is not planned again', () {
    FarmTask boss() => FarmTask(
      kind: TaskKind.weeklyBoss,
      phase: BuildPhase.talents,
      title: 'Jefe semanal: Garra',
      runs: 2,
      resin: 30,
      bossKey: 'Dvalin',
    );
    final monday = DateTime(2026, 11, 23);
    final fresh = scheduleResin([boss()], start: monday);
    expect(fresh.days.first.runs.single.count, 1);
    final done = scheduleResin(
      [boss()],
      start: monday,
      weeklyDoneThisWeek: {'Dvalin'},
    );
    expect(done.days.first.runs, isEmpty);
    // Next Monday it is back.
    expect(done.days[7].runs.single.task.title, 'Jefe semanal: Garra');
  });

  test('Inventory reads EXP books, ores and Mora by their ids', () {
    final inventory = Inventory.fromJson({
      'booksCharacter': ['3', '2', '1'],
      'booksWeapon': ['9', '8', '7'],
      'mora': '5000',
      'materials': {'material:x': '4'},
    });
    expect(inventory.owned('material:104003'), 3);
    expect(inventory.owned('material:104001'), 1);
    expect(inventory.owned('material:104012'), 8);
    expect(inventory.owned('material:202'), 5000);
    expect(inventory.owned('material:x'), 4);
    expect(inventory.owned('material:y'), 0);
  });

  group('Checking tasks', () {
    late AppDatabase db;
    late ProviderContainer container;

    Future<void> mount(WidgetTester tester, TaskRef task) async {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            resinClockProvider.overrideWithValue(() => t0),
            catalogProvider.overrideWith(
              (ref) => Completer<CatalogBundle>().future,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return Column(
                    children: [
                      TextButton(
                        key: const ValueKey('go'),
                        onPressed: () => completeTask(context, ref, task),
                        child: const Text('Marcar'),
                      ),
                      TextButton(
                        key: const ValueKey('undo'),
                        onPressed: () async {
                          final done = await ref.read(doneTodayProvider.future);
                          if (context.mounted) {
                            await undoTask(context, ref, done.single);
                          }
                        },
                        child: const Text('Desmarcar'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<T> read<T extends Object>(
      WidgetTester tester,
      Future<T> Function() f,
    ) async => (await tester.runAsync(f))!;

    testWidgets(
      'Done now: resin is spent, the counts are final, undo restores',
      (tester) async {
        await mount(
          tester,
          const TaskRef(
            key: 'resina|Ayaka|Dominio de talentos',
            label: 'Dominio de talentos × 2',
            original: 40,
            materialIds: ['material:a', 'material:b'],
          ),
        );
        await tester.tap(find.byKey(const ValueKey('go')));
        await tester.pumpAndSettle();
        expect(
          find.text('¿Lo hiciste ahora o ya lo habías hecho antes?'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('done-now')));
        await tester.pumpAndSettle();
        expect(find.text('¿Cuánto tienes ahora?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('count-material:a')),
          '12',
        );
        await tester.enterText(
          find.byKey(const ValueKey('count-material:b')),
          '3',
        );
        await tester.tap(find.byKey(const ValueKey('counts-save')));
        await tester.pumpAndSettle();

        final resin = await read(
          tester,
          () => container.read(resinProvider.future),
        );
        expect(resin.originalAt(t0), 160);
        var inventory = await read(
          tester,
          () => container.read(buildRepositoryProvider).inventory(),
        );
        expect(inventory.owned('material:a'), 12);
        expect(inventory.owned('material:b'), 3);

        await tester.tap(find.byKey(const ValueKey('undo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('undo-revert')));
        await tester.pumpAndSettle();
        expect(
          (await read(
            tester,
            () => container.read(resinProvider.future),
          )).originalAt(t0),
          200,
        );
        inventory = await read(
          tester,
          () => container.read(buildRepositoryProvider).inventory(),
        );
        expect(inventory.owned('material:a'), 0);
        expect(
          await read(tester, () => container.read(doneTodayProvider.future)),
          isEmpty,
        );
      },
    );

    testWidgets(
      'Already done before: nothing is spent, the weekly boss counts',
      (tester) async {
        await mount(
          tester,
          const TaskRef(
            key: 'resina|Ayaka|Jefe semanal',
            label: 'Jefe semanal × 1',
            original: 30,
            bossKey: 'Dvalin',
          ),
        );
        await tester.tap(find.byKey(const ValueKey('go')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('done-before')));
        await tester.pumpAndSettle();
        final resin = await read(
          tester,
          () => container.read(resinProvider.future),
        );
        expect(resin.originalAt(t0), 200);
        expect(
          await read(
            tester,
            () => container.read(weeklyBossesDoneProvider.future),
          ),
          {'Dvalin'},
        );
      },
    );

    testWidgets(
      'Commissions add Primogems and Mora, with a reminder to adjust',
      (tester) async {
        await mount(
          tester,
          const TaskRef(
            key: 'rutina|daily',
            label: 'Encargos diarios',
            primogems: 60,
            commission: true,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('go')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Se sumaron 60 Protogemas'), findsOneWidget);
        expect(find.textContaining('puedes ajustar'), findsOneWidget);
        final wallet = await read(
          tester,
          () => container.read(walletProvider.future),
        );
        expect(wallet.primogems, 60);
        var inventory = await read(
          tester,
          () => container.read(buildRepositoryProvider).inventory(),
        );
        expect(inventory.mora, Wallet.defaultCommissionMora);

        await tester.tap(find.byKey(const ValueKey('undo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('undo-revert')));
        await tester.pumpAndSettle();
        expect(
          (await read(
            tester,
            () => container.read(walletProvider.future),
          )).primogems,
          0,
        );
        inventory = await read(
          tester,
          () => container.read(buildRepositoryProvider).inventory(),
        );
        expect(inventory.mora, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
