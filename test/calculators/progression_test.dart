import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/catalog/domain/catalog.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

void main() {
  final bundle = CatalogBundle.parse(
    File('assets/catalog/seed-v1.json').readAsStringSync(),
  );
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  final amber = bundle.records.firstWhere((r) => r.name == 'Amber');
  final bow = bundle.records.firstWhere((r) => r.id == 'weapon:15401');
  final sword = bundle.records.firstWhere((r) => r.id == 'weapon:11302');
  const start = ProgressionState(level: 1, ascension: 0);
  const end = ProgressionState(level: 90, ascension: 6);
  test('Character 1–90 exact XP and six ascensions with feeding plan', () {
    final result = calculateProgression(bundle, amber, rules, start, end);
    expect(result.experience, 8362650);
    expect(result.materials['material:202'], result.levelingMora + 420000);
    expect(result.expItems.values.every((v) => v > 0), isTrue);
    expect(result.surplus, lessThan(7000));
    expect(result.levelingMora * 5, result.experience + result.surplus);
  });
  test('Character 80–90 includes last ascension only when needed', () {
    final before = calculateProgression(
      bundle,
      amber,
      rules,
      const ProgressionState(level: 80, ascension: 5),
      end,
    );
    final after = calculateProgression(
      bundle,
      amber,
      rules,
      const ProgressionState(level: 80, ascension: 6),
      end,
    );
    expect(before.experience, 3423125);
    expect(
      before.materials['material:202']! - after.materials['material:202']!,
      120000,
    );
    expect(after.materials.length, 1);
  });
  test('Four-star and three-star weapon XP use separate tables', () {
    expect(
      calculateProgression(bundle, bow, rules, start, end).experience,
      6042650,
    );
    expect(
      calculateProgression(bundle, sword, rules, start, end).experience,
      3988200,
    );
    expect(
      calculateProgression(
        bundle,
        bow,
        rules,
        const ProgressionState(level: 40, ascension: 2),
        end,
      ).experience,
      5546525,
    );
  });
  test('Talents 1/10/10 charge only two talents and crowns', () {
    final result = calculateProgression(
      bundle,
      amber,
      rules,
      end,
      const ProgressionState(level: 90, ascension: 6, talents: [1, 10, 10]),
    );
    expect(result.experience, 0);
    expect(result.materials['material:202'], 3305000);
    final crown = bundle.records.firstWhere(
      (r) => r.name == 'Corona de la sabiduría',
    );
    expect(result.materials[crown.id], 2);
  });
  test('Partial talent progression charges only missing levels', () {
    final result = calculateProgression(
      bundle,
      amber,
      rules,
      const ProgressionState(level: 90, ascension: 6, talents: [1, 9, 10]),
      const ProgressionState(level: 90, ascension: 6, talents: [1, 10, 10]),
    );
    expect(result.materials['material:202'], 700000);
  });
  test('Partial XP and equal states', () {
    expect(
      calculateProgression(
        bundle,
        amber,
        rules,
        const ProgressionState(level: 1, ascension: 0, experience: 500),
        const ProgressionState(level: 2, ascension: 0),
      ).experience,
      500,
    );
    expect(
      calculateProgression(bundle, amber, rules, end, end).materials,
      isEmpty,
    );
  });
  test('Reject impossible levels, caps, partial XP and talents', () {
    for (final bad in [
      const ProgressionState(level: 90, ascension: 0),
      const ProgressionState(level: 1, ascension: 6),
      const ProgressionState(level: 20, ascension: 0, experience: 1),
      const ProgressionState(level: 1, ascension: 0, experience: 1000),
      const ProgressionState(level: 90, ascension: 6, talents: [1, 13, 10]),
      const ProgressionState(level: 40, ascension: 1, talents: [2, 1, 1]),
    ]) {
      expect(
        () => calculateProgression(bundle, amber, rules, start, bad),
        throwsA(isA<CalculationException>()),
      );
    }
    expect(
      () => calculateProgression(bundle, amber, rules, end, start),
      throwsA(isA<CalculationException>()),
    );
  });
}
