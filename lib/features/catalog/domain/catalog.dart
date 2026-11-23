import 'dart:convert';

enum CatalogKind { character, weapon, material, activity }

enum Reliability { verified, pending, rejected }

class CatalogValidationException implements Exception {
  const CatalogValidationException(this.message);
  final String message;
  @override
  String toString() => 'Catálogo inválido: $message';
}

Never _fail(String path, String message) =>
    throw CatalogValidationException('$path: $message');
Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) _fail(path, 'se esperaba un objeto');
  return value;
}

String _string(Object? value, String path) {
  if (value is! String || value.trim().isEmpty || value.length > 2000) {
    _fail(path, 'texto vacío o inválido');
  }
  return value;
}

int _integer(Object? value, String path, int min, int max) {
  if (value is! int || value < min || value > max) {
    _fail(path, 'entero fuera de rango $min–$max');
  }
  return value;
}

List<dynamic> _list(Object? value, String path) {
  if (value is! List) _fail(path, 'se esperaba una lista');
  return value;
}

List<String> _strings(Object? value, String path) {
  final result = _list(value, path).map((v) => _string(v, path)).toList();
  if (result.toSet().length != result.length) _fail(path, 'valores duplicados');
  return List.unmodifiable(result);
}

String _date(Object? value, String path) {
  final result = _string(value, path);
  final date = DateTime.tryParse(result);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(result) ||
      date == null ||
      date.toIso8601String().substring(0, 10) != result) {
    _fail(path, 'fecha ISO inválida');
  }
  return result;
}

String _url(Object? value, String path) {
  final result = _string(value, path);
  final uri = Uri.tryParse(result);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    _fail(path, 'URL HTTPS inválida');
  }
  return result;
}

T _enum<T extends Enum>(List<T> values, Object? value, String path) {
  for (final item in values) {
    if (item.name == value) return item;
  }
  _fail(path, 'valor no reconocido');
}

class Provenance {
  Provenance._(
    this.source,
    this.revision,
    this.gameVersion,
    this.verifiedAt,
    this.reliability,
    this.license,
    this.method,
  );
  final String source, revision, gameVersion, verifiedAt, license, method;
  final Reliability reliability;
  factory Provenance.fromJson(Object? value, String path) {
    final json = _object(value, path);
    return Provenance._(
      _url(json['source'], '$path.source'),
      _string(json['revision'], '$path.revision'),
      _string(json['gameVersion'], '$path.gameVersion'),
      _date(json['verifiedAt'], '$path.verifiedAt'),
      _enum(Reliability.values, json['reliability'], '$path.reliability'),
      _string(json['license'], '$path.license'),
      _string(json['method'], '$path.method'),
    );
  }
}

class Requirement {
  Requirement._(this.kind, this.stage, this.materials);
  final String kind;
  final int stage;
  final Map<String, int> materials;
  factory Requirement.fromJson(Object? value, String path) {
    final json = _object(value, path);
    final kind = _string(json['kind'], '$path.kind');
    if (!['ascension', 'talent'].contains(kind)) {
      _fail(path, 'tipo de requisito inválido');
    }
    final stage = _integer(
      json['stage'],
      '$path.stage',
      kind == 'talent' ? 2 : 1,
      kind == 'talent' ? 10 : 6,
    );
    final amounts = _object(json['materials'], '$path.materials');
    if (amounts.isEmpty) _fail(path, 'requisito sin materiales');
    return Requirement._(
      kind,
      stage,
      Map.unmodifiable(
        amounts.map(
          (id, count) =>
              MapEntry(id, _integer(count, '$path.$id', 1, 1000000000)),
        ),
      ),
    );
  }
}

class ExperienceStep {
  ExperienceStep._(this.fromLevel, this.experience, this.mora);
  final int fromLevel, experience, mora;
  factory ExperienceStep.fromJson(Object? value, String path) {
    final json = _object(value, path);
    return ExperienceStep._(
      _integer(json['fromLevel'], path, 1, 999),
      _integer(json['experience'], path, 1, 1000000000),
      _integer(json['mora'], path, 0, 1000000000),
    );
  }
}

class ProgressionData {
  ProgressionData._(
    this.weaponType,
    this.element,
    this.region,
    this.maxLevel,
    this.requirements,
    this.experience,
  );
  final String weaponType;
  final String? element, region;
  final int? maxLevel;
  final List<Requirement> requirements;
  final List<ExperienceStep> experience;
}

class MaterialData {
  MaterialData._(this.category, this.sourceHints);
  final String category;
  final List<String> sourceHints;
}

class ActivityData {
  ActivityData._(
    this.type,
    this.days,
    this.resinCost,
    this.weeklyLimit,
    this.unlockRank,
    this.rewards,
  );
  final String type;
  final List<int> days;
  final int? resinCost, weeklyLimit, unlockRank;
  // Known reward identities only; no probability or guaranteed amount implied.
  final List<String> rewards;
}

class CatalogRecord {
  CatalogRecord._(
    this.id,
    this.kind,
    this.name,
    this.rarity,
    this.provenance,
    this.pendingFields,
    this.additionalSources,
    this.activityIds,
    this.progression,
    this.material,
    this.activity,
  );
  final String id, name;
  final CatalogKind kind;
  final int? rarity;
  final Provenance provenance;
  final List<String> pendingFields, additionalSources, activityIds;
  final ProgressionData? progression;
  final MaterialData? material;
  final ActivityData? activity;

  bool get isFullyVerified =>
      provenance.reliability == Reliability.verified && pendingFields.isEmpty;

  /// Future calculators must explicitly name every field they consume.
  bool canUseFields(Iterable<String> fields) =>
      provenance.reliability == Reliability.verified &&
      fields.every((field) {
        if (pendingFields.contains(field)) return false;
        return switch (field) {
          'requirements' => progression != null,
          'experience' => progression?.experience.isNotEmpty ?? false,
          'levelCaps' => progression?.maxLevel != null,
          'element' => progression?.element != null,
          'weaponType' => progression != null,
          'category' => material != null,
          'days' => activity?.days.isNotEmpty ?? false,
          'resinCost' => activity?.resinCost != null,
          'weeklyLimit' => activity?.weeklyLimit != null,
          'rewards' => activity != null,
          _ => false,
        };
      });

  factory CatalogRecord.fromJson(Object? value) {
    final json = _object(value, 'record');
    final id = _string(json['id'], 'id');
    final kind = _enum(CatalogKind.values, json['kind'], '$id.kind');
    if (!RegExp('^${kind.name}:[a-zA-Z0-9:_-]+\$').hasMatch(id)) {
      _fail(id, 'identificador inestable o tipo incorrecto');
    }
    final name = _string(json['name'], '$id.name');
    final provenance = Provenance.fromJson(
      json['provenance'],
      '$id.provenance',
    );
    final pending = _strings(json['pendingFields'], '$id.pendingFields');
    final sources = _strings(
      json['additionalSources'],
      '$id.additionalSources',
    );
    for (final source in sources) {
      _url(source, id);
    }
    final activityIds = kind == CatalogKind.activity
        ? <String>[]
        : _strings(json['activityIds'], '$id.activityIds');
    final rarity =
        kind == CatalogKind.activity ||
            (kind == CatalogKind.material && json['rarity'] == null)
        ? null
        : _integer(json['rarity'], '$id.rarity', 1, 5);
    if (kind == CatalogKind.material &&
        rarity == null &&
        !pending.contains('rarity')) {
      _fail(id, 'rareza no documentada sin marcar como pendiente');
    }
    ProgressionData? progression;
    MaterialData? material;
    ActivityData? activity;
    if (kind == CatalogKind.character || kind == CatalogKind.weapon) {
      final requirements = _list(
        json['requirements'],
        id,
      ).map((v) => Requirement.fromJson(v, id)).toList();
      final keys = requirements.map((r) => '${r.kind}:${r.stage}').toSet();
      if (keys.length != requirements.length) _fail(id, 'etapas duplicadas');
      if (kind == CatalogKind.weapon &&
          requirements.any((r) => r.kind == 'talent')) {
        _fail(id, 'un arma no tiene talentos');
      }
      final experience = _list(
        json['experience'],
        id,
      ).map((v) => ExperienceStep.fromJson(v, id)).toList();
      if (experience.map((r) => r.fromLevel).toSet().length !=
          experience.length) {
        _fail(id, 'niveles de experiencia duplicados');
      }
      final maxLevel = json['maxLevel'] == null
          ? null
          : _integer(json['maxLevel'], id, 2, 1000);
      if (maxLevel == null && !pending.contains('levelCaps')) {
        _fail(id, 'faltan límites de nivel sin marcar como pendientes');
      }
      if (!pending.contains('experience') &&
          (maxLevel == null ||
              experience.length != maxLevel - 1 ||
              experience.any((r) => r.fromLevel >= maxLevel))) {
        _fail(id, 'tabla de experiencia incompleta');
      }
      if (!pending.contains('requirements')) {
        if (requirements.where((r) => r.kind == 'ascension').length != 6) {
          _fail(id, 'ascensiones incompletas');
        }
        if (kind == CatalogKind.character &&
            requirements.where((r) => r.kind == 'talent').length != 9) {
          _fail(id, 'talentos incompletos');
        }
      }
      progression = ProgressionData._(
        _string(json['weaponType'], id),
        kind == CatalogKind.character ? _string(json['element'], id) : null,
        json['region'] == null ? null : _string(json['region'], id),
        maxLevel,
        List.unmodifiable(requirements),
        List.unmodifiable(experience),
      );
    } else if (kind == CatalogKind.material) {
      material = MaterialData._(
        _string(json['category'], id),
        _strings(json['sourceHints'], id),
      );
    } else {
      final type = _string(json['activityType'], id);
      if (![
        'talentDomain',
        'weaponDomain',
        'normalBoss',
        'weeklyBoss',
        'leyLine',
        'other',
      ].contains(type)) {
        _fail(id, 'actividad desconocida');
      }
      final days = _list(
        json['days'],
        id,
      ).map((v) => _integer(v, id, 1, 7)).toList();
      if (days.toSet().length != days.length) _fail(id, 'días duplicados');
      if (days.isEmpty && !pending.contains('days')) {
        _fail(id, 'disponibilidad ausente');
      }
      final resin = json['resinCost'] == null
          ? null
          : _integer(json['resinCost'], id, 0, 1000);
      if (resin == null && !pending.contains('resinCost')) {
        _fail(id, 'coste de resina ausente');
      }
      final weekly = json['weeklyLimit'] == null
          ? null
          : _integer(json['weeklyLimit'], id, 1, 100);
      if (type == 'weeklyBoss' &&
          weekly == null &&
          !pending.contains('weeklyLimit')) {
        _fail(id, 'límite semanal ausente');
      }
      final rank = json['unlockRank'] == null
          ? null
          : _integer(json['unlockRank'], id, 1, 100);
      activity = ActivityData._(
        type,
        List.unmodifiable(days),
        resin,
        weekly,
        rank,
        _strings(json['rewards'], id),
      );
    }
    return CatalogRecord._(
      id,
      kind,
      name,
      rarity,
      provenance,
      pending,
      sources,
      List.unmodifiable(activityIds),
      progression,
      material,
      activity,
    );
  }
}

Object? _canonical(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

class CatalogBundle {
  CatalogBundle._(
    this.version,
    this.sequence,
    this.gameVersion,
    this.createdAt,
    this.versionSource,
    this.records,
    this.canonicalJson,
  );
  final String version, gameVersion, createdAt, versionSource, canonicalJson;
  final int sequence;
  final List<CatalogRecord> records;
  factory CatalogBundle.parse(String text) {
    if (text.length > 10000000) _fail('archivo', 'supera 10 MB de texto');
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _fail('archivo', 'JSON mal formado');
    }
    final json = _object(decoded, 'catalog');
    _integer(json['schemaVersion'], 'schemaVersion', 1, 1);
    final version = _string(json['version'], 'version');
    if (!RegExp(r'^[a-zA-Z0-9._-]{1,80}$').hasMatch(version)) {
      _fail('version', 'formato inválido');
    }
    final sequence = _integer(json['sequence'], 'sequence', 1, 2147483647);
    final gameVersion = _string(json['gameVersion'], 'gameVersion');
    final date = _date(json['createdAt'], 'createdAt');
    final versionSource = _url(json['versionSource'], 'versionSource');
    final rawRecords = _list(json['records'], 'records');
    if (rawRecords.isEmpty || rawRecords.length > 10000) {
      _fail('records', 'cantidad inválida');
    }
    final records = rawRecords.map(CatalogRecord.fromJson).toList();
    final byId = <String, CatalogRecord>{};
    for (final record in records) {
      if (byId.containsKey(record.id)) _fail(record.id, 'ID duplicado');
      if (record.provenance.gameVersion != gameVersion) {
        _fail(record.id, 'versión de juego inconsistente');
      }
      byId[record.id] = record;
    }
    for (final record in records) {
      void reference(String id, CatalogKind kind) {
        if (byId[id]?.kind != kind) {
          _fail(record.id, 'referencia inválida: $id');
        }
        if (record.provenance.reliability == Reliability.verified &&
            byId[id]!.provenance.reliability != Reliability.verified) {
          _fail(record.id, 'dependencia sin verificar: $id');
        }
      }

      for (final id in record.activityIds) {
        reference(id, CatalogKind.activity);
      }
      for (final row in record.progression?.requirements ?? <Requirement>[]) {
        for (final id in row.materials.keys) {
          reference(id, CatalogKind.material);
        }
      }
      for (final id in record.activity?.rewards ?? <String>[]) {
        reference(id, CatalogKind.material);
      }
    }
    return CatalogBundle._(
      version,
      sequence,
      gameVersion,
      date,
      versionSource,
      List.unmodifiable(records),
      jsonEncode(_canonical(json)),
    );
  }
}
