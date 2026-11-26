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
  final spanish = jsonDecode(
    File('assets/catalog/nombres-es.json').readAsStringSync(),
  ) as Map<String, dynamic>;
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
  CatalogRecord named(String name) =>
      bundle.records.firstWhere((r) => r.name == name);
  String nameOf(String id) => bundle.records.firstWhere((r) => r.id == id).name;

  test('World Level sets ley line yield and must match the AR', () {
    expect(LeyLineRates.forWorldLevel(0).mora, 12000);
    expect(LeyLineRates.forWorldLevel(5).experience, 102500);
    expect(LeyLineRates.forWorldLevel(8).mora, 60000);
    expect(
      () => LeyLineRates.forWorldLevel(10),
      throwsA(isA<CalculationException>()),
    );
    expect(LeyLineRates.highestFor(35), 4);
    expect(LeyLineRates.highestFor(60), 9);
    expect(
      () => LeyLineRates.checkAccount(9, 35),
      throwsA(isA<CalculationException>()),
    );
    expect(LeyLineRates.checkAccount(8, 57), isNull);
    expect(LeyLineRates.checkAccount(7, 57), isNotNull); // lowered by one
    Matcher impossible = throwsA(isA<CalculationException>());
    expect(() => LeyLineRates.checkAccount(4, 57), impossible);
    // AR 58: World Level 9 needs its quest, so 8 is sure and 7 is the floor.
    expect(() => LeyLineRates.checkAccount(1, 58), impossible);
    expect(() => LeyLineRates.checkAccount(6, 58), impossible);
    expect(LeyLineRates.checkAccount(7, 58), isNotNull);
    expect(LeyLineRates.checkAccount(8, 58), isNull);
    expect(LeyLineRates.checkAccount(9, 60), isNull);
    // AR 25 before the ascension quest is still World Level 1.
    expect(LeyLineRates.checkAccount(0, 25), isNotNull);
    expect(LeyLineRates.checkAccount(2, 25), isNull);
    expect(() => LeyLineRates.checkAccount(3, 25), impossible);
    expect(LeyLineRates.checkAccount(0, 10), isNull);
  });

  test('Names and pictures arrive with the catalog', () {
    expect(
      bundle.records.firstWhere((r) => r.id == 'material:104003').image,
      'https://gi.deve.sh/materials/heros-wit/icon.png',
    );
    expect(nameOf('material:101217'), 'Loto kalpa');
    expect(nameOf('material:104003'), 'Ingenio del héroe');
    expect(named('Mavuika').progression!.gender, 'Femenino');
    expect(named('Mavuika').progression!.element, 'Pyro');
    expect(named('Mavuika').progression!.weaponType, 'Mandoble');
    final characters = bundle.records.where(
      (r) => r.kind == CatalogKind.character,
    );
    expect(characters.every((r) => r.progression!.gender != null), isTrue);
    expect(
      {for (final r in characters) r.progression!.element},
      containsAll([
        'Anemo',
        'Cryo',
        'Dendro',
        'Electro',
        'Geo',
        'Hydro',
        'Pyro',
      ]),
    );
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
          bundle.records.firstWhere((r) => r.id == e.key).material?.category ==
          'Material de jefe semanal',
    );
    // 6 weekly boss materials per talent 7→10 (crowns are counted apart).
    expect(weekly.fold(0, (sum, e) => sum + e.value), 12);

    // Listed like the game groups them: specialty, world boss, gems from
    // smallest to biggest, common drops by tier, then talent materials.
    final ordered = planInventory(
      bundle: bundle,
      record: mavuika,
      result: calculateProgression(
        bundle,
        mavuika,
        rules,
        const ProgressionState(level: 1, ascension: 0),
        const ProgressionState(level: 90, ascension: 6, talents: [1, 10, 10]),
      ),
      ownedBooks: const [0, 0, 0],
      ownedMaterials: const {},
    ).lines.map((l) => bundle.records.firstWhere((r) => r.id == l.id)).toList();
    expect(ordered.map((r) => r.material!.category).toList().sublist(0, 9), [
      'Especialidad local',
      'Material de jefe',
      'Gema de ascensión',
      'Gema de ascensión',
      'Gema de ascensión',
      'Gema de ascensión',
      'Botín común',
      'Botín común',
      'Botín común',
    ]);
    expect(ordered[2].material!.craft, isNull); // sliver first
    expect(ordered[3].material!.craft!.fromId, ordered[2].id);
    expect(ordered[7].material!.craft!.fromId, ordered[6].id);
    expect(ordered.last.material!.category, 'Libro de talento'); // crown

    final empty = planInventory(
      bundle: bundle,
      record: mavuika,
      result: result,
      ownedBooks: const [0, 0, 0],
      ownedMaterials: const {},
    );
    expect(empty.expMissing, result.experience);
    expect(empty.expRuns, (result.experience + 122499) ~/ 122500);
    // Mora is split by purpose and adds up to the total.
    expect(
      result.levelingMora + result.ascensionMora + result.talentMora,
      result.materials['material:202'],
    );
    expect(
      result.talentMora,
      2 *
          (12500 +
              17500 +
              25000 +
              30000 +
              37500 +
              120000 +
              260000 +
              450000 +
              700000),
    );
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

  test('Spare Teachings and Guides become the Philosophies a talent needs', () {
    final skirk = named('Skirk');
    final result = calculateProgression(
      bundle,
      skirk,
      rules,
      const ProgressionState(level: 90, ascension: 6, talents: [1, 9, 8]),
      const ProgressionState(level: 90, ascension: 6, talents: [1, 10, 10]),
    );
    final philosophy = bundle.records.firstWhere(
      (r) =>
          result.materials.containsKey(r.id) &&
          r.material?.category == 'Libro de talento' &&
          r.material?.craft != null,
    );
    final guide = philosophy.material!.craft!.fromId;
    final teaching = bundle.records
        .firstWhere((r) => r.id == guide)
        .material!
        .craft!
        .fromId;
    // Only the top tier is needed for these talents.
    expect(result.materials.containsKey(guide), isFalse);
    expect(result.materials.containsKey(teaching), isFalse);
    final need = result.materials[philosophy.id]!;
    expect(need, 44);
    final plan = planInventory(
      bundle: bundle,
      record: skirk,
      result: result,
      ownedBooks: const [0, 0, 0],
      ownedMaterials: {philosophy.id: 7, guide: 46, teaching: 51},
    );
    // 51 Teachings → 17 Guides; 63 Guides → 21 Philosophies.
    final line = plan.lines.firstWhere((l) => l.id == philosophy.id);
    expect(line.crafted, 21);
    expect(line.missing, 44 - 7 - 21);
    expect(plan.used, {philosophy.id: 7, guide: 46, teaching: 51});
    expect(
      plan.craftingMora,
      17 *
              bundle.records
                  .firstWhere((r) => r.id == guide)
                  .material!
                  .craft!
                  .mora +
          21 * philosophy.material!.craft!.mora,
    );
  }, skip: skip);
}
