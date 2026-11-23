import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/catalog/data/genshin_api_source.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/progression/domain/inventory_plan.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

// Real data from the archive cached by tool/build_offline_catalog.py.
void main() {
  final zip = File(
    '.catalog-cache/genshin-api-62af3592e7ef4498d90e68e7967096c5aabc8f33.zip',
  );
  final skip = zip.existsSync() ? false : 'sin caché local de genshin-api';
  late final CatalogBundle bundle = catalogFromArchive(
    zip.readAsBytesSync(),
    UpstreamRevision(
      '62af3592e7ef4498d90e68e7967096c5aabc8f33',
      DateTime.utc(2026, 11, 15, 18, 40),
    ),
    spanishNames:
        ((jsonDecode(
                      File(
                        'assets/catalog/nombres-es.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>)['names']
                as Map<String, dynamic>)
            .cast<String, String>(),
  );
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  CatalogRecord named(String name) =>
      bundle.records.firstWhere((r) => r.name == name);
  String nameOf(String id) => bundle.records.firstWhere((r) => r.id == id).name;

  test('Names arrive in Spanish', () {
    expect(nameOf('material:101217'), 'Loto kalpa');
    expect(nameOf('material:104003'), 'Ingenio del héroe');
    expect(bundle.records.any((r) => r.name == 'Mavuika'), isTrue);
  }, skip: skip);

  test('Mavuika 50/50 → 90 with two crowned talents', () {
    final mavuika = named('Mavuika');
    final result = calculateProgression(
      bundle,
      mavuika,
      rules,
      const ProgressionState(level: 50, ascension: 2),
      const ProgressionState(level: 90, ascension: 6, talents: [1, 10, 10]),
    );
    final weekly = result.materials.entries.where(
      (e) =>
          bundle.records
              .firstWhere((r) => r.id == e.key)
              .material
              ?.category ==
          'Material de jefe semanal',
    );
    // 6 weekly boss materials per talent 7→10 (crowns are counted apart).
    expect(weekly.fold(0, (sum, e) => sum + e.value), 12);

    final empty = planInventory(
      bundle: bundle,
      record: mavuika,
      result: result,
      ownedBooks: const [0, 0, 0],
      ownedMaterials: const {},
    );
    expect(empty.expMissing, result.experience);
    expect(empty.expRuns, (result.experience + 119999) ~/ 120000);
    expect(empty.levelWithOwned, 50);

    final rich = planInventory(
      bundle: bundle,
      record: mavuika,
      result: result,
      ownedBooks: const [1000, 0, 0],
      ownedMaterials: const {},
      ownedMora: 100000000,
    );
    expect(rich.expMissing, 0);
    expect(rich.expRuns, 0);
    expect(rich.levelWithOwned, 90);
    expect(rich.moraMissing, 0);
  }, skip: skip);

  test('Spare lower tiers are crafted 3→1 only as far as needed', () {
    final mavuika = named('Mavuika');
    final result = calculateProgression(
      bundle,
      mavuika,
      rules,
      const ProgressionState(level: 1, ascension: 0),
      const ProgressionState(level: 90, ascension: 6),
    );
    final gems = bundle.records
        .where(
          (r) =>
              result.materials.containsKey(r.id) &&
              r.material?.category == 'Gema de ascensión',
        )
        .toList();
    expect(gems, hasLength(4));
    final sliver = gems.firstWhere((g) => g.material!.craft == null);
    final fragment = gems.firstWhere(
      (g) => g.material!.craft?.fromId == sliver.id,
    );
    // Need 1 sliver and 9 fragments; the 30 spare slivers make 10 fragments:
    // 9 cover the fragments and the extra one counts toward the chunks.
    final plan = planInventory(
      bundle: bundle,
      record: mavuika,
      result: result,
      ownedBooks: const [0, 0, 0],
      ownedMaterials: {sliver.id: 31},
    );
    final line = plan.lines.firstWhere((l) => l.id == fragment.id);
    expect(result.materials[sliver.id], 1);
    expect(line.needed, 9);
    expect(line.crafted, 9);
    expect(line.missing, 0);
    expect(plan.craftingMora, 10 * fragment.material!.craft!.mora);
  }, skip: skip);
}
