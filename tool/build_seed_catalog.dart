// Reproducible factual extract. No artwork, stories or descriptions are bundled.
// Run: dart run tool/build_seed_catalog.dart
import 'dart:convert';
import 'dart:io';

const revision = '8e5badd60b5d894284ccc927a56c9683529d2592';
const root = 'https://raw.githubusercontent.com/theBowja/genshin-db/$revision';
const verifiedAt = '2026-11-19';
final client = HttpClient();
final materialSlugs = <int, String>{};

Future<Map<String, dynamic>> readSource(
  String category,
  String slug, [
  String language = 'Spanish',
]) async {
  final path = 'src/data/$language/$category/$slug.json';
  final file = File('.catalog-cache/$revision/${path.replaceAll('/', '_')}');
  if (!await file.exists()) {
    final response = await (await client.getUrl(Uri.parse('$root/$path')))
        .close();
    if (response.statusCode != 200) {
      throw StateError('$path: ${response.statusCode}');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(await utf8.decoder.bind(response).join());
  }
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

Map<String, Object?> provenance(
  String category,
  String slug, {
  String status = 'verified',
}) => {
  'source': '$root/src/data/Spanish/$category/$slug.json',
  'revision': revision,
  'gameVersion': '7.2',
  'verifiedAt': verifiedAt,
  'reliability': status,
  'license': 'MIT',
  'method': 'Revisión de campos factuales de genshin-db; no certificación de HoYoverse.',
};

List<Map<String, Object?>> costs(
  Map<String, dynamic> source,
  String prefix,
  String kind,
) {
  final rows = <Map<String, Object?>>[];
  final table = source['costs'] as Map<String, dynamic>;
  for (final entry in table.entries) {
    if (!entry.key.startsWith(prefix)) continue;
    final stage = int.parse(entry.key.substring(prefix.length));
    final amounts = <String, int>{};
    for (final item in entry.value as List) {
      final id = item['id'] as int;
      final name = item['name'] as String;
      materialSlugs[id] = name.toLowerCase().replaceAll(
        RegExp('[^a-z0-9]'),
        '',
      );
      amounts['material:$id'] = item['count'] as int;
    }
    rows.add({'kind': kind, 'stage': stage, 'materials': amounts});
  }
  return rows;
}

void verifyCosts(Map<String, dynamic> en, Map<String, dynamic> es) {
  String numericCosts(Map<String, dynamic> source) {
    final table = source['costs'] as Map<String, dynamic>;
    final keys = table.keys.toList()..sort();
    return [
      for (final key in keys)
        '$key:${(table[key] as List).map((v) => '${v['id']}=${v['count']}').join(',')}',
    ].join(';');
  }

  if (numericCosts(en) != numericCosts(es)) {
    throw StateError('Localized cost tables disagree');
  }
}

Future<void> main() async {
  final records = <Map<String, Object?>>[];
  try {
    for (final slug in ['amber', 'kaeya', 'lisa']) {
      final en = await readSource('characters', slug, 'English');
      final es = await readSource('characters', slug);
      final talents = await readSource('talents', slug, 'English');
      final esTalents = await readSource('talents', slug);
      // Cross-language IDs and material counts must agree, not just names.
      if (en['id'] != es['id']) {
        throw StateError('Character translation mismatch');
      }
      verifyCosts(en, es);
      verifyCosts(talents, esTalents);
      final ascension = costs(en, 'ascend', 'ascension');
      final talentCosts = costs(talents, 'lvl', 'talent');
      if (ascension.length != 6 ||
          talentCosts.length != 9 ||
          esTalents['costs'] == null) {
        throw StateError('Incomplete progression: $slug');
      }
      records.add({
        'id': 'character:${en['id']}',
        'kind': 'character',
        'name': es['name'],
        'rarity': en['rarity'],
        'element': es['elementText'],
        'region': es['region'],
        'weaponType': es['weaponText'],
        'maxLevel': null,
        'requirements': [...ascension, ...talentCosts],
        'experience': [],
        'activityIds': <String>[],
        'pendingFields': ['experience', 'levelCaps', 'constellationBonuses'],
        'provenance': provenance('characters', slug),
        'additionalSources': ['$root/src/data/Spanish/talents/$slug.json'],
      });
    }
    for (final slug in [
      'favoniuswarbow',
      'harbingerofdawn',
      'thrillingtalesofdragonslayers',
    ]) {
      final en = await readSource('weapons', slug, 'English');
      final es = await readSource('weapons', slug);
      if (en['id'] != es['id']) throw StateError('Weapon translation mismatch');
      verifyCosts(en, es);
      records.add({
        'id': 'weapon:${en['id']}',
        'kind': 'weapon',
        'name': es['name'],
        'rarity': en['rarity'],
        'weaponType': es['weaponText'],
        'maxLevel': null,
        'requirements': costs(en, 'ascend', 'ascension'),
        'experience': [],
        'activityIds': <String>[],
        'pendingFields': ['experience', 'levelCaps'],
        'provenance': provenance('weapons', slug),
        'additionalSources': [],
      });
    }
    final weekdays = {
      'Lunes': 1,
      'Martes': 2,
      'Miércoles': 3,
      'Jueves': 4,
      'Viernes': 5,
      'Sábado': 6,
      'Domingo': 7,
    };
    for (final entry in materialSlugs.entries) {
      final es = await readSource('materials', entry.value);
      if (es['id'] != entry.key) {
        throw StateError('Material ID mismatch: ${entry.value}');
      }
      records.add({
        'id': 'material:${entry.key}',
        'kind': 'material',
        'name': es['name'],
        'rarity': es['rarity'],
        'category': es['typeText'],
        'sourceHints': es['sources'] ?? [],
        'activityIds': <String>[],
        'pendingFields': <String>[if (es['rarity'] == null) 'rarity'],
        'provenance': provenance('materials', entry.value),
        'additionalSources': [],
      });
    }
    final activities = <Map<String, Object?>>[];
    for (final family in [
      'domainofmasteryfrostedaltar',
      'domainofmasteryfrozenabyss',
      'domainofmasteryrealmofslumber',
      'domainofforgerycityofreflections',
      'domainofforgerysubmergedvalley',
      'domainofforgeryruinsofthirstingcapital',
    ]) {
      for (final tier in ['i', 'ii', 'iii', 'iv']) {
        final slug = '$family$tier';
        final es = await readSource('domains', slug);
        activities.add({
          'id': 'activity:domain:${es['id']}',
          'kind': 'activity',
          'name': es['name'],
          'activityType': family.contains('mastery')
              ? 'talentDomain'
              : 'weaponDomain',
          'days': [for (final day in es['daysOfWeek'] as List) weekdays[day]!],
          'resinCost': null,
          'weeklyLimit': null,
          'unlockRank': es['unlockRank'],
          'rewards': [
            for (final item in es['rewardPreview'] as List)
              if (materialSlugs.containsKey(item['id']))
                'material:${item['id']}',
          ],
          'pendingFields': ['resinCost', 'rewardDistribution'],
          'provenance': provenance('domains', slug),
          'additionalSources': [],
        });
      }
    }
    for (final slug in [
      'pyroregisvine',
      'cryoregisvine',
      'electrohypostasis',
      'stormterror',
    ]) {
      final es = await readSource('enemies', slug);
      activities.add({
        'id': 'activity:enemy:${es['id']}',
        'kind': 'activity',
        'name': es['name'],
        'activityType': slug == 'stormterror' ? 'weeklyBoss' : 'normalBoss',
        'days': <int>[],
        'resinCost': null,
        'weeklyLimit': null,
        'unlockRank': null,
        // Source preview contains fractional estimates. Never treat them as exact drops.
        'rewards': [
          for (final item in es['rewardPreview'] as List)
            if (materialSlugs.containsKey(item['id'])) 'material:${item['id']}',
        ],
        'pendingFields': [
          'days',
          'resinCost',
          'weeklyLimit',
          'rewardDistribution',
        ],
        'provenance': provenance('enemies', slug), 'additionalSources': [],
      });
    }
    for (final record in records) {
      final required = <String>{};
      if (record['kind'] == 'material') required.add(record['id'] as String);
      for (final row in (record['requirements'] as List? ?? [])) {
        required.addAll((row['materials'] as Map).keys.cast<String>());
      }
      // Mora is shared by nearly every activity and must not create spurious links.
      required.remove('material:202');
      record['activityIds'] = [
        for (final activity in activities)
          if ((activity['rewards'] as List).any(required.contains))
            activity['id'],
      ];
    }
    records.addAll(activities);
    records.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final output = {
      'schemaVersion': 1,
      'version': '2026.11.19.1',
      'sequence': 1,
      'gameVersion': '7.2',
      'createdAt': verifiedAt,
      'versionSource': 'https://genshin.hoyoverse.com/m/es/news/detail/167131',
      'records': records,
    };
    final target = File('assets/catalog/seed-v1.json');
    await target.parent.create(recursive: true);
    await target.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
    stdout.writeln(
      'Catalog: ${records.length} records (${materialSlugs.length} materials).',
    );
  } finally {
    client.close();
  }
}
