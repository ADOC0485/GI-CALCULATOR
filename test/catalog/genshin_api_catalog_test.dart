import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genshin_progress_planner/features/catalog/data/genshin_api_catalog.dart';
import 'package:genshin_progress_planner/features/progression/domain/progression_calculator.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';

Map<String, Object?> _cost(int mora, Map<String, int> items) => {
  'mora': mora,
  'materials': [
    for (final e in items.entries) {'slug': e.key, 'quantity': e.value},
  ],
};

List<Map<String, Object?>> _levels(int max, int Function(int) exp) => [
  for (var level = 1; level <= max; level++)
    {'level': level, 'exp_to_next': level == max ? null : exp(level)},
];

Map<String, Object?> _files() => {
  'progression.json': {
    'max_level': {
      'character': 90,
      'weapon': {'1': 70, '2': 70, '3': 90, '4': 90, '5': 90},
    },
    'character': {'exp_per_mora': 5, 'levels': _levels(90, (l) => 1000 * l)},
    'weapon': {
      'exp_per_mora': 10,
      'by_rarity': {
        for (final r in [1, 2, 3, 4, 5])
          '$r': _levels(r <= 2 ? 70 : 90, (l) => 100 * l),
      },
    },
  },
  'materials/gem.json': {
    'id': 104111,
    'name': 'Gem',
    'rarity': 2,
    'category': 'ascension-gem',
    'dropped_by': ['big-boss'],
    'source': {'type': 'boss'},
  },
  'materials/book.json': {
    'id': 104301,
    'name': 'Book',
    'rarity': 2,
    'category': 'talent-book',
    'source': {
      'type': 'domain',
      'name': 'Domain of Mastery: Test',
      'days': ['monday', 'thursday', 'sunday'],
    },
  },
  'materials/ore.json': {
    'id': 114001,
    'name': 'Ore',
    'rarity': 2,
    'category': 'weapon-material',
    'source': {
      'type': 'domain',
      'name': 'Domain of Forgery: Test',
      'days': ['tuesday', 'friday', 'sunday'],
    },
  },
  for (final slug in ['traveler-a', 'traveler-b', 'hero'])
    'characters/$slug.json': {
      'id': slug == 'hero' ? 10000099 : 10000005,
      'name': slug,
      'rarity': 5,
      'vision': 'Pyro',
      'weapon': 'Sword',
      'nation': 'Mondstadt',
      'ascension_costs': [
        for (var p = 1; p <= 6; p++)
          {'phase': p, ..._cost(20000 * p, {'gem': p})},
      ],
      'talent_costs': {
        for (final (i, key) in [
          'normal_attack',
          'elemental_skill',
          'elemental_burst',
        ].indexed)
          key: [
            for (var l = 2; l <= 10; l++)
              {'level': l, ..._cost(1000, {'book': i + 1})},
          ],
      },
    },
  'weapons/blade.json': {
    'id': 11501,
    'name': 'Blade',
    'rarity': 5,
    'type': 'Sword',
    'ascension_costs': [
      for (var p = 1; p <= 6; p++)
        {'phase': p, ..._cost(10000, {'ore': p})},
    ],
  },
};

void main() {
  final rules = ProgressionRules(
    File('assets/rules/progression-v1.json').readAsStringSync(),
  );
  final bundle = buildGenshinApiCatalog(
    files: _files(),
    revision: _sha,
    committedAt: DateTime.utc(2026, 11, 20, 12),
  );

  test('Converts records with stable IDs and domain schedules', () {
    final ids = bundle.records.map((r) => r.id).toSet();
    expect(bundle.version, 'genshin-api-0123456789ab-c3');
    expect(ids, contains('character:10000099'));
    expect(ids, contains('character:10000005-traveler-a'));
    expect(ids, contains('character:10000005-traveler-b'));
    expect(ids, containsAll(['weapon:11501', 'material:104301', moraId]));
    final domain = bundle.records.firstWhere(
      (r) => r.id == 'activity:domain:domain-of-mastery-test',
    );
    expect(domain.activity!.days, [1, 4, 7]);
    expect(domain.activity!.type, 'talentDomain');
    expect(domain.activity!.rewards, ['material:104301']);
    final hero = bundle.records.firstWhere((r) => r.id == 'character:10000099');
    expect(hero.progression!.weaponType, 'Espada ligera');
    expect(hero.activityIds, ['activity:domain:domain-of-mastery-test']);
    expect(hero.isFullyVerified, isTrue);
  });

  test('Talents are counted once per talent, using its own table', () {
    final hero = bundle.records.firstWhere((r) => r.id == 'character:10000099');
    final result = calculateProgression(
      bundle,
      hero,
      rules,
      const ProgressionState(level: 1, ascension: 0),
      const ProgressionState(level: 1, ascension: 0, talents: [1, 1, 1]),
    );
    expect(result.materials, isEmpty);
    final talents = calculateProgression(
      bundle,
      hero,
      rules,
      const ProgressionState(level: 90, ascension: 6),
      const ProgressionState(level: 90, ascension: 6, talents: [3, 1, 10]),
    );
    // Normal attack: 2 levels × 1 book; burst: 9 levels × 3 books.
    expect(talents.materials['material:104301'], 2 + 27);
    expect(talents.materials[moraId], 11 * 1000);
  });

  test('Uses the catalog EXP table instead of the bundled rules', () {
    final blade = bundle.records.firstWhere((r) => r.id == 'weapon:11501');
    final result = calculateProgression(
      bundle,
      blade,
      rules,
      const ProgressionState(level: 1, ascension: 0),
      const ProgressionState(level: 90, ascension: 6),
    );
    expect(result.experience, 100 * (89 * 90 ~/ 2));
    expect(result.materials['material:114001'], 21);
  });

  test('Later upstream commits get a later sequence', () {
    final later = buildGenshinApiCatalog(
      files: _files(),
      revision: 'f' * 40,
      committedAt: DateTime.utc(2026, 12, 1),
    );
    expect(later.sequence, greaterThan(bundle.sequence));
  });

  test('Rejects archives that reference unknown materials', () {
    final files = _files();
    (files['weapons/blade.json']! as Map)['ascension_costs'] = [
      {'phase': 1, ..._cost(1, {'missing': 1})},
    ];
    expect(
      () => buildGenshinApiCatalog(
        files: files,
        revision: _sha,
        committedAt: DateTime.utc(2026),
      ),
      throwsA(isA<GenshinApiFormatException>()),
    );
  });
}
