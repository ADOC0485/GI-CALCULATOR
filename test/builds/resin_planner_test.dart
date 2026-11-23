import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  GenshinBuild mavuika() => GenshinBuild(
    id: 'b1',
    characterId: id('Mavuika'),
    weaponId: id('Sombra de la Marea'),
    characterNow: const ProgressionState(level: 50, ascension: 2),
    characterGoal: const ProgressionState(
      level: 90,
      ascension: 6,
      talents: [1, 10, 10],
    ),
    weaponNow: const ProgressionState(level: 20, ascension: 0),
  );

  test('Build splits into level, weapon and talents in that order', () {
    final phases = buildNeeds(
      bundle: bundle,
      rules: rules,
      build: mavuika(),
      inventory: const Inventory(),
    );
    expect(phases.map((p) => p.phase), [
      BuildPhase.characterLevel,
      BuildPhase.weaponLevel,
      BuildPhase.talents,
    ]);
    expect(phases.first.result.talentMora, 0);
    expect(phases.last.result.experience, 0);
  }, skip: skip);

  test('Owned items go to the first phase that needs them', () {
    final mora = buildNeeds(
      bundle: bundle,
      rules: rules,
      build: mavuika(),
      inventory: const Inventory(mora: 1000000),
    );
    expect(mora.first.plan.moraOwned, 1000000);
    // Whatever level-up did not need is left for later phases.
    final left = (1000000 - mora.first.plan.moraTotal).clamp(0, 1000000);
    expect(mora[1].plan.moraOwned, left);
  }, skip: skip);

  test('Resin is spent by priority and respects domain days', () {
    final phases = buildNeeds(
      bundle: bundle,
      rules: rules,
      build: mavuika(),
      inventory: const Inventory(),
    );
    final plan = farmTasks(
      bundle: bundle,
      phases: phases,
      rates: LeyLineRates.forWorldLevel(8),
    );
    final kinds = plan.tasks.map((t) => t.kind).toSet();
    expect(
      kinds,
      containsAll([
        TaskKind.worldBoss,
        TaskKind.expLeyLine,
        TaskKind.moraLeyLine,
        TaskKind.weaponDomain,
        TaskKind.talentDomain,
        TaskKind.weeklyBoss,
      ]),
    );
    // The crown cannot be farmed with resin; specialties and drops are free.
    expect(plan.free.any((f) => f.title.contains('eventos')), isTrue);
    expect(plan.free.any((f) => f.title.contains('recógela')), isTrue);

    final schedule = scheduleResin(
      plan.tasks,
      start: DateTime(2026, 11, 23), // Monday
    );
    expect(schedule.finish, isNotNull);
    for (final day in schedule.days) {
      expect(day.resin, lessThanOrEqualTo(200));
      for (final run in day.runs) {
        if (run.task.days.isNotEmpty) {
          expect(run.task.days, contains(day.date.weekday));
        }
      }
    }
    // Day one goes to the character level (phase 1), not to talents.
    expect(
      schedule.days.first.runs.every(
        (r) => r.task.phase == BuildPhase.characterLevel,
      ),
      isTrue,
    );
    // The weekly boss is done at most once per week.
    final weekly = plan.tasks.firstWhere((t) => t.kind == TaskKind.weeklyBoss);
    final perWeek = <int, int>{};
    for (final day in schedule.days) {
      for (final run in day.runs.where((r) => r.task == weekly)) {
        final week = day.date.difference(DateTime(2026, 11, 23)).inDays ~/ 7;
        perWeek.update(week, (n) => n + run.count, ifAbsent: () => run.count);
      }
    }
    expect(perWeek.values.every((n) => n == 1), isTrue);
    expect(perWeek.length, weekly.runs);
  }, skip: skip);
}
