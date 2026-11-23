import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/agenda/agenda_page.dart';
import 'package:genshin_progress_planner/features/builds/domain/build.dart';
import 'package:genshin_progress_planner/features/builds/domain/resin_planner.dart';
import 'package:genshin_progress_planner/features/catalog/data/genshin_api_source.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/progression/domain/inventory_plan.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

void main() {
  final zip = File(
    '.catalog-cache/genshin-api-62af3592e7ef4498d90e68e7967096c5aabc8f33.zip',
  );
  final skip = zip.existsSync() ? false : 'sin caché local de genshin-api';
  final spanish =
      jsonDecode(File('assets/catalog/nombres-es.json').readAsStringSync())
          as Map<String, dynamic>;
  Map<String, String> part(String key) =>
      (spanish[key] as Map<String, dynamic>).cast<String, String>();
  late final CatalogBundle bundle = catalogFromArchive(
    zip.readAsBytesSync(),
    UpstreamRevision(
      '62af3592e7ef4498d90e68e7967096c5aabc8f33',
      DateTime.utc(2026, 11, 15, 18, 40),
    ),
    spanishNames: part('names'),
    genders: part('genders'),
  );
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  String id(String name) => bundle.records.firstWhere((r) => r.name == name).id;
  GenshinBuild full(String bid, String name) => GenshinBuild(
    id: bid,
    characterId: id(name),
    characterNow: const ProgressionState(level: 1, ascension: 0),
    characterGoal: const ProgressionState(
      level: 90,
      ascension: 6,
      talents: [10, 10, 10],
    ),
  );
  final monday = DateTime(2026, 11, 23);

  test('Builds share resin; the first one in the list goes first', () {
    final plan = planAgenda(
      bundle: bundle,
      rules: rules,
      builds: [full('a', 'Mavuika'), full('b', 'Nahida')],
      inventory: const Inventory(),
      start: monday,
    );
    final first = plan.schedule.days.first.runs;
    expect(first, isNotEmpty);
    expect(first.every((r) => r.task.owner == 'Mavuika'), isTrue);
    expect(plan.finishByBuild.keys, ['Mavuika', 'Nahida']);
    expect(plan.finishByBuild['Mavuika'], isNotNull);
    expect(
      plan.finishByBuild['Mavuika']!.isAfter(plan.finishByBuild['Nahida']!),
      isFalse,
    );
    for (final day in plan.schedule.days) {
      expect(day.resin, lessThanOrEqualTo(200));
    }
  }, skip: skip);

  test('Weekly bosses: once each per week, first three claims discounted', () {
    final plan = planAgenda(
      bundle: bundle,
      rules: rules,
      builds: [full('a', 'Mavuika'), full('b', 'Nahida')],
      inventory: const Inventory(),
      start: monday,
    );
    final byWeek = <int, List<PlannedRun>>{};
    for (final day in plan.schedule.days) {
      for (final run in day.runs.where(
        (r) => r.task.kind == TaskKind.weeklyBoss,
      )) {
        byWeek
            .putIfAbsent(day.date.difference(monday).inDays ~/ 7, () => [])
            .add(run);
      }
    }
    expect(byWeek, isNotEmpty);
    for (final runs in byWeek.values) {
      final keys = runs.map((r) => r.task.bossKey).toList();
      expect(keys.toSet().length, keys.length); // never the same boss twice
      expect(runs.every((r) => r.count == 1), isTrue);
      expect(runs.take(3).every((r) => r.resin == 30), isTrue);
      expect(runs.skip(3).every((r) => r.resin == 60), isTrue);
    }
  }, skip: skip);

  test('Progress is the share of material items already owned', () {
    BuildProgress progress(Inventory inventory) => planAgenda(
      bundle: bundle,
      rules: rules,
      builds: [full('a', 'Mavuika')],
      inventory: inventory,
      start: monday,
    ).progress['a']!;
    final empty = progress(const Inventory());
    expect(empty.percent, 0);
    expect(empty.needed, greaterThan(0));
    // Owning every material needed for level and talents means 100 %.
    final all = <String, int>{};
    final phases = buildNeeds(
      bundle: bundle,
      rules: rules,
      build: full('a', 'Mavuika'),
      inventory: const Inventory(),
    );
    for (final p in phases) {
      for (final l in p.plan.lines) {
        all.update(l.id, (v) => v + l.needed, ifAbsent: () => l.needed);
      }
    }
    final owned = progress(Inventory(materials: all));
    expect(owned.percent, 100);
    expect(owned.expMissing, greaterThan(0)); // EXP and Mora are shown apart
    // Half of one material gives a value strictly between both.
    final some = progress(Inventory(materials: {all.keys.first: all.values.first}));
    expect(some.fraction, greaterThan(0));
    expect(some.fraction, lessThan(1));
  }, skip: skip);

  test('What you own goes to the first build that needs it', () {
    final pool = InventoryPool(const Inventory(mora: 3000000));
    final a = buildNeedsFromPool(
      bundle: bundle,
      rules: rules,
      build: full('a', 'Mavuika'),
      pool: pool,
    );
    final b = buildNeedsFromPool(
      bundle: bundle,
      rules: rules,
      build: full('b', 'Nahida'),
      pool: pool,
    );
    expect(a.first.plan.moraOwned, 3000000);
    expect(b.first.plan.moraOwned, lessThan(3000000));
  }, skip: skip);

  test('Using books: big ones first, small ones to finish', () {
    final owned = [2, 3, 10];
    InventoryPool.consume(owned, characterExpItems, 47000);
    // 2 purple (40 000) + 1 blue (5 000) + 2 green (2 000).
    expect(owned, [0, 2, 8]);
  });
}
