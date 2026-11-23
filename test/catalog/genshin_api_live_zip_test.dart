import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/catalog/data/genshin_api_source.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

// Uses the archive cached by tool/build_offline_catalog.py when present.
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
  );
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  int count(CatalogKind k) => bundle.records.where((r) => r.kind == k).length;

  test('Real genshin-api archive converts to a valid catalog', () {
    expect(count(CatalogKind.character), 138);
    expect(count(CatalogKind.weapon), 253);
    expect(count(CatalogKind.material), greaterThan(500));
    expect(count(CatalogKind.activity), greaterThan(20));
  }, skip: skip);

  test('Every complete character and 3–5★ weapon is calculable', () {
    var calculable = 0;
    for (final record in bundle.records.where(
      (r) =>
          r.pendingFields.isEmpty &&
          (r.kind == CatalogKind.character ||
              (r.kind == CatalogKind.weapon && r.rarity! >= 3)),
    )) {
      calculateProgression(
        bundle,
        record,
        rules,
        const ProgressionState(level: 1, ascension: 0),
        const ProgressionState(
          level: 90,
          ascension: 6,
          talents: [10, 10, 10],
        ),
      );
      calculable++;
    }
    expect(calculable, greaterThan(370));
  }, skip: skip);

  test('Nahida matches the genshin-api planner example', () {
    final nahida = bundle.records.firstWhere((r) => r.name == 'Nahida');
    final result = calculateProgression(
      bundle,
      nahida,
      rules,
      const ProgressionState(level: 1, ascension: 0),
      const ProgressionState(level: 90, ascension: 6, talents: [9, 9, 9]),
    );
    expect(result.experience, 8362650);
    expect(result.materials['material:101217'], 168); // Kalpalata Lotus
    // Ascension 420 000 + talents 3 × 952 500 (1→9) + leveling.
    expect(
      result.materials['material:202'],
      420000 + 3 * 952500 + result.levelingMora,
    );
  }, skip: skip);
}
