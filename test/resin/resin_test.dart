import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/data/database/app_database.dart';
import 'package:genshin_progress_planner/data/database/database_provider.dart';
import 'package:genshin_progress_planner/features/builds/domain/resin_planner.dart';
import 'package:genshin_progress_planner/features/resin/resin_bar.dart';
import 'package:genshin_progress_planner/features/resin/resin_state.dart';

void main() {
  final t0 = DateTime(2026, 11, 23, 10);

  test('Original Resin regenerates 1 every 8 minutes up to 200', () {
    final r = ResinState(original: 20, updatedAt: t0);
    expect(r.originalAt(t0), 20);
    expect(r.originalAt(t0.add(const Duration(minutes: 7, seconds: 59))), 20);
    expect(r.originalAt(t0.add(const Duration(minutes: 8))), 21);
    expect(
      r.nextIn(t0.add(const Duration(minutes: 3))),
      const Duration(minutes: 5),
    );
    // 180 points left × 8 minutes = 24 hours.
    expect(r.fullIn(t0), const Duration(hours: 24));
    expect(r.originalAt(t0.add(const Duration(days: 3))), 200);
    expect(r.nextIn(t0.add(const Duration(days: 3))), isNull);
  });

  test('Refills above the cap stay; totals count every type', () {
    final r = ResinState(
      original: 260,
      updatedAt: t0,
      condensed: 2,
      fragile: 1,
      transient: 1,
    );
    expect(r.originalAt(t0.add(const Duration(hours: 5))), 260);
    expect(r.normalAt(t0), 260 + 60 + 60);
    expect(r.totalAt(t0), 380 + 80);
    expect(ResinState.fromJson(r.toJson())!.totalAt(t0), r.totalAt(t0));
  });

  test('Condensed Resin goes to domains and ley lines, never to bosses', () {
    FarmTask task(TaskKind kind, int resin) => FarmTask(
      kind: kind,
      phase: BuildPhase.characterLevel,
      title: kind.label,
      runs: 1,
      resin: resin,
    );
    final boss = task(TaskKind.worldBoss, 40);
    final ley = task(TaskKind.expLeyLine, 20);
    final schedule = scheduleResin(
      [boss, ley],
      start: DateTime(2026, 11, 23),
      startResin: 40,
      startCondensed: 1,
    );
    final runs = schedule.days.first.runs;
    expect(runs.firstWhere((r) => r.task == boss).condensed, 0);
    expect(runs.firstWhere((r) => r.task == ley).condensed, 20);
  });

  testWidgets('Top bar shows the countdown and saves edits', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          resinClockProvider.overrideWithValue(() => t0),
        ],
        child: const MaterialApp(home: Scaffold(body: ResinBar())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('200/200'), findsOneWidget);
    expect(find.text('Llena'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resin-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resin-original')), '20');
    await tester.enterText(find.byKey(const ValueKey('resin-condensed')), '2');
    await tester.tap(find.byKey(const ValueKey('resin-save')));
    await tester.pumpAndSettle();
    expect(find.text('20/200'), findsOneWidget);
    expect(find.textContaining('+1 en 08:00'), findsOneWidget);
    expect(find.text('Total 100'), findsOneWidget);
    // More than 5 condensed is not allowed, as in the game.
    await tester.tap(find.byKey(const ValueKey('resin-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resin-condensed')), '6');
    await tester.tap(find.byKey(const ValueKey('resin-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Solo puedes tener 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('On a phone the top bar is one slim strip', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          resinClockProvider.overrideWithValue(() => t0),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [ResinBar()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resin-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resin-original')), '37');
    await tester.enterText(find.byKey(const ValueKey('resin-condensed')), '2');
    await tester.enterText(find.byKey(const ValueKey('resin-fragile')), '4');
    await tester.enterText(find.byKey(const ValueKey('resin-transient')), '1');
    await tester.tap(find.byKey(const ValueKey('resin-save')));
    await tester.pumpAndSettle();
    expect(find.text('37/200'), findsOneWidget);
    expect(find.textContaining('reinicio'), findsOneWidget);
    expect(tester.getSize(find.byType(ResinBar)).height, lessThan(64));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
