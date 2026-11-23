import 'dart:convert';

import '../domain/catalog.dart';

/// Repository whose `data/` folder feeds the online catalog.
const genshinApiRepository = 'devesh-anand/genshin-api';

/// Game ID of Mora, shared with the seed catalog so totals stay comparable.
const moraId = 'material:202';

const _weaponTypes = {
  'Sword': 'Espada ligera',
  'Claymore': 'Mandoble',
  'Polearm': 'Lanza',
  'Bow': 'Arco',
  'Catalyst': 'Catalizador',
};

const _categories = {
  'common-drop': 'Botín común',
  'weapon-material': 'Material de ascensión de arma',
  'talent-book': 'Libro de talento',
  'local-specialty': 'Especialidad local',
  'boss-drop': 'Material de jefe',
  'weekly-boss-drop': 'Material de jefe semanal',
  'ascension-gem': 'Gema de ascensión',
  'weapon-billet': 'Lingote de arma',
  'exp-material': 'Material de EXP',
};

const _weekdays = {
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
};

const _talentKeys = ['normal_attack', 'elemental_skill', 'elemental_burst'];

class GenshinApiFormatException implements Exception {
  const GenshinApiFormatException(this.message);
  final String message;
  @override
  String toString() => 'Datos de genshin-api no reconocidos: $message';
}

Map<String, dynamic> _map(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  throw GenshinApiFormatException(path);
}

List<dynamic> _listOrEmpty(Object? value) => value is List ? value : const [];

String _humanize(String slug) => slug
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

String _slugify(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _date(DateTime value) =>
    value.toUtc().toIso8601String().substring(0, 10);

/// Converts the JSON files under genshin-api's `data/` folder into a catalog
/// bundle validated by [CatalogBundle.parse].
///
/// [files] maps paths relative to `data/` (for example
/// `characters/nahida.json`) to their decoded JSON.
CatalogBundle buildGenshinApiCatalog({
  required Map<String, Object?> files,
  required String revision,
  required DateTime committedAt,
}) {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
    throw const GenshinApiFormatException('revisión de commit inválida');
  }
  final day = _date(committedAt);
  final gameVersion = 'genshin-api $day';
  String source(String path) =>
      'https://raw.githubusercontent.com/$genshinApiRepository/$revision/data/$path';
  Map<String, Object?> provenance(String path) => {
    'source': source(path),
    'revision': revision,
    'gameVersion': gameVersion,
    'verifiedAt': day,
    'reliability': 'verified',
    'license': 'ISC (declarada en package.json de genshin-api)',
    'method':
        'Conversión automática desde genshin-api (datos de yatta.moe, Enka.Network y la wiki de Fandom); no es certificación de HoYoverse.',
  };

  Iterable<MapEntry<String, Map<String, dynamic>>> folder(String name) sync* {
    final keys =
        files.keys
            .where((k) => k.startsWith('$name/') && k.endsWith('.json'))
            .toList()
          ..sort();
    for (final key in keys) {
      yield MapEntry(key, _map(files[key], key));
    }
  }

  final progression = _map(files['progression.json'], 'progression.json');
  List<Map<String, Object?>> experience(List<dynamic> levels, int divisor) => [
    for (final row in levels.map((r) => _map(r, 'progression.json')))
      if (row['exp_to_next'] is int && (row['exp_to_next'] as int) > 0)
        {
          'fromLevel': row['level'],
          'experience': row['exp_to_next'],
          'mora': (row['exp_to_next'] as int) ~/ divisor,
        },
  ];
  final characterProgression = _map(
    progression['character'],
    'progression.character',
  );
  final characterExperience = experience(
    _listOrEmpty(characterProgression['levels']),
    characterProgression['exp_per_mora'] as int? ?? 5,
  );
  final characterMaxLevel =
      _map(progression['max_level'], 'progression.max_level')['character']
          as int;
  final weaponProgression = _map(progression['weapon'], 'progression.weapon');
  final weaponDivisor = weaponProgression['exp_per_mora'] as int? ?? 10;
  final weaponTables = _map(
    weaponProgression['by_rarity'],
    'progression.weapon.by_rarity',
  );
  final weaponMaxLevels = _map(
    _map(progression['max_level'], 'progression.max_level')['weapon'],
    'progression.max_level.weapon',
  );

  // Materials: game IDs keep compatibility with the seed catalog.
  final materialIds = <String, String>{};
  final materials = <String, Map<String, Object?>>{};
  final activities = <String, Map<String, Object?>>{};
  for (final entry in folder('materials')) {
    final json = entry.value;
    final slug = entry.key.substring('materials/'.length, entry.key.length - 5);
    final id = 'material:${json['id']}';
    if (json['id'] is! int) throw GenshinApiFormatException(entry.key);
    materialIds[slug] = id;
    final rarity = json['rarity'];
    final validRarity = rarity is int && rarity >= 1 && rarity <= 5;
    final hints = <String>{};
    final activityIds = <String>[];
    final from = json['source'];
    if (from is Map<String, dynamic>) {
      switch (from['type']) {
        case 'domain':
          final name = from['name'];
          if (name is String && name.isNotEmpty) {
            hints.add('Dominio: $name');
            final days = [
              for (final d in _listOrEmpty(from['days']))
                if (_weekdays[d] != null) _weekdays[d]!,
            ]..sort();
            final activityId = 'activity:domain:${_slugify(name)}';
            final activity = activities.putIfAbsent(
              activityId,
              () => {
                'id': activityId,
                'kind': 'activity',
                'name': name,
                'activityType': json['category'] == 'talent-book'
                    ? 'talentDomain'
                    : json['category'] == 'weapon-material'
                    ? 'weaponDomain'
                    : 'other',
                'days': days.toSet().toList(),
                'resinCost': null,
                'weeklyLimit': null,
                'unlockRank': null,
                'rewards': <String>[],
                'pendingFields': [
                  'resinCost',
                  'rewardDistribution',
                  if (days.isEmpty) 'days',
                ],
                'provenance': provenance(entry.key),
                'additionalSources': <String>[],
              },
            );
            (activity['rewards'] as List<String>).add(id);
            activityIds.add(activityId);
          }
        case 'local-specialty':
          final region = from['region'] ?? json['region'];
          hints.add(
            region is String
                ? 'Especialidad local de $region'
                : 'Especialidad local',
          );
        default:
          final description = from['description'];
          if (description is String && description.isNotEmpty) {
            hints.add(description);
          }
      }
    }
    final droppedBy = _listOrEmpty(json['dropped_by']).whereType<String>();
    if (droppedBy.isNotEmpty) {
      hints.add('Lo sueltan: ${droppedBy.map(_humanize).join(', ')}');
    }
    materials[id] = {
      'id': id,
      'kind': 'material',
      'name': json['name'],
      'rarity': validRarity ? rarity : null,
      'category':
          _categories[json['category']] ??
          (json['category'] is String
              ? _humanize(json['category'] as String)
              : 'Otro'),
      'sourceHints': hints.toList(),
      'activityIds': activityIds,
      'pendingFields': [if (!validRarity) 'rarity'],
      'provenance': provenance(entry.key),
      'additionalSources': <String>[],
    };
  }
  materials[moraId] ??= {
    'id': moraId,
    'kind': 'material',
    'name': 'Mora',
    'rarity': 3,
    'category': 'Moneda',
    'sourceHints': ['Recompensas de todo el juego'],
    'activityIds': <String>[],
    'pendingFields': <String>[],
    'provenance': provenance('progression.json'),
    'additionalSources': <String>[],
  };

  Map<String, int> costs(Object? row, String path) {
    final json = _map(row, path);
    final result = <String, int>{};
    final mora = json['mora'];
    if (mora is int && mora > 0) result[moraId] = mora;
    for (final item in _listOrEmpty(json['materials'])) {
      final material = _map(item, path);
      final id = materialIds[material['slug']];
      final quantity = material['quantity'];
      if (id == null || quantity is! int) {
        throw GenshinApiFormatException('$path: material ${material['slug']}');
      }
      result.update(id, (old) => old + quantity, ifAbsent: () => quantity);
    }
    return result;
  }

  List<String> relatedActivities(Iterable<Map<String, Object?>> rows) {
    final result = <String>{};
    for (final row in rows) {
      for (final id in (row['materials'] as Map<String, int>).keys) {
        result.addAll(materials[id]?['activityIds'] as List<String>? ?? []);
      }
    }
    return result.toList()..sort();
  }

  // Characters: travelers share a game ID per gender, so they get a suffix.
  final characterFiles = folder('characters').toList();
  final idCounts = <Object?, int>{};
  for (final entry in characterFiles) {
    idCounts.update(entry.value['id'], (c) => c + 1, ifAbsent: () => 1);
  }
  final characters = <Map<String, Object?>>[];
  for (final entry in characterFiles) {
    final json = entry.value;
    final slug = entry.key.substring(
      'characters/'.length,
      entry.key.length - 5,
    );
    final id = idCounts[json['id']] == 1
        ? 'character:${json['id']}'
        : 'character:${json['id']}-$slug';
    final requirements = <Map<String, Object?>>[
      for (final row in _listOrEmpty(json['ascension_costs']))
        {
          'kind': 'ascension',
          'stage': _map(row, entry.key)['phase'],
          'materials': costs(row, entry.key),
        },
    ];
    final talents = json['talent_costs'];
    if (talents is Map<String, dynamic>) {
      for (var i = 0; i < _talentKeys.length; i++) {
        for (final row in _listOrEmpty(talents[_talentKeys[i]])) {
          requirements.add({
            'kind': 'talent',
            'stage': _map(row, entry.key)['level'],
            'materials': costs(row, entry.key),
            'talentIndex': i,
          });
        }
      }
    }
    final vision = json['vision'];
    final nation = json['nation'];
    characters.add({
      'id': id,
      'kind': 'character',
      'name': json['name'],
      'rarity': json['rarity'],
      'element': vision is String && vision.isNotEmpty ? vision : 'Ninguno',
      'region': nation is String && nation.isNotEmpty ? nation : null,
      'weaponType': _weaponTypes[json['weapon']] ?? json['weapon'],
      'maxLevel': characterMaxLevel,
      'requirements': requirements,
      'experience': characterExperience,
      'activityIds': relatedActivities(requirements),
      'pendingFields': [if (requirements.isEmpty) 'requirements'],
      'provenance': provenance(entry.key),
      'additionalSources': <String>[],
    });
  }

  final weapons = <Map<String, Object?>>[];
  for (final entry in folder('weapons')) {
    final json = entry.value;
    final rarity = json['rarity'];
    final requirements = <Map<String, Object?>>[
      for (final row in _listOrEmpty(json['ascension_costs']))
        {
          'kind': 'ascension',
          'stage': _map(row, entry.key)['phase'],
          'materials': costs(row, entry.key),
        },
    ];
    weapons.add({
      'id': 'weapon:${json['id']}',
      'kind': 'weapon',
      'name': json['name'],
      'rarity': rarity,
      'weaponType': _weaponTypes[json['type']] ?? json['type'],
      'maxLevel': weaponMaxLevels['$rarity'],
      'requirements': requirements,
      'experience': experience(
        _listOrEmpty(weaponTables['$rarity']),
        weaponDivisor,
      ),
      'activityIds': relatedActivities(requirements),
      'pendingFields': [if (requirements.isEmpty) 'requirements'],
      'provenance': provenance(entry.key),
      'additionalSources': <String>[],
    });
  }

  for (final activity in activities.values) {
    activity['rewards'] = (activity['rewards'] as List<String>).toSet().toList()
      ..sort();
  }

  final catalog = {
    'schemaVersion': 2,
    'version': 'genshin-api-${revision.substring(0, 12)}',
    // Commit time keeps later upstream revisions ordered after earlier ones.
    'sequence': committedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    'gameVersion': gameVersion,
    'createdAt': day,
    'versionSource': 'https://github.com/$genshinApiRepository/commit/$revision',
    'records': [
      ...characters,
      ...weapons,
      ...materials.values,
      ...activities.values,
    ],
  };
  return CatalogBundle.parse(jsonEncode(catalog));
}
