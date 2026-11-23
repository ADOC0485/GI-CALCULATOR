import 'dart:convert';

import '../../catalog/domain/catalog.dart';

class CalculationException implements Exception {
  const CalculationException(this.message);
  final String message;
  @override
  String toString() => message;
}

void require(bool valid, String message) {
  if (!valid) throw CalculationException(message);
}

class ProgressionRules {
  ProgressionRules(String json)
    : data = jsonDecode(json) as Map<String, dynamic> {
    for (final key in ['character', 'weapon3', 'weapon4', 'weapon5']) {
      final values = data[key] as List;
      require(
        values.length == 90 && values.first == 0,
        'Tabla de EXP inválida.',
      );
      for (var i = 1; i < values.length; i++) {
        require(
          values[i] is int && values[i] > values[i - 1],
          'EXP no creciente.',
        );
      }
    }
  }
  final Map<String, dynamic> data;
  String get version => data['version'] as String;
  List<int> table(CatalogRecord record) => List<int>.from(
    data[record.kind == CatalogKind.character
            ? 'character'
            : 'weapon${record.rarity}']
        as List,
  );
  static const supported = {
    'character:10000006',
    'character:10000015',
    'character:10000021',
    'weapon:11302',
    'weapon:14302',
    'weapon:15401',
  };
  static const caps = [20, 40, 50, 60, 70, 80, 90];
  static const floors = [1, 20, 40, 50, 60, 70, 80];
  static const talentCaps = [1, 1, 2, 4, 6, 8, 10];
}

/// Level caps a level can show in game: 50 can be 50/50 or 50/60.
List<int> capsForLevel(int level) => [
  for (var a = 0; a < ProgressionRules.caps.length; a++)
    if (level >= ProgressionRules.floors[a] && level <= ProgressionRules.caps[a])
      ProgressionRules.caps[a],
];

/// Ascension phase for a level as shown in game; [ascended] only matters
/// when the level sits on a cap (50/50 vs 50/60).
int ascensionFor(int level, {bool ascended = false}) {
  final caps = capsForLevel(level);
  require(caps.isNotEmpty, 'El nivel debe estar entre 1 y 90.');
  final cap = ascended && caps.length > 1 ? caps[1] : caps.first;
  return ProgressionRules.caps.indexOf(cap);
}

class ProgressionState {
  const ProgressionState({
    required this.level,
    required this.ascension,
    this.experience = 0,
    this.talents = const [1, 1, 1],
  });
  final int level, ascension, experience;
  final List<int> talents;
}

class ProgressionResult {
  ProgressionResult(
    this.experience,
    this.levelingMora,
    this.materials,
    this.expItems,
    this.surplus, {
    List<int> xpTable = const [0],
    this.fromLevel = 1,
    this.toLevel = 1,
    int startExperience = 0,
    this.ascensionMora = 0,
    this.talentMora = 0,
  }) : _xp = xpTable,
       _start = startExperience;
  final int experience, levelingMora, surplus, fromLevel, toLevel;

  /// Mora spent on ascensions and on talents, already inside [materials].
  final int ascensionMora, talentMora;
  final Map<String, int> materials, expItems;
  final List<int> _xp;
  final int _start;

  /// Level reached by feeding [exp] EXP, ascending along the way.
  int levelWith(int exp) {
    var level = fromLevel;
    while (level < toLevel && _xp[level] <= _start + exp) {
      level++;
    }
    return level;
  }
}

/// Total EXP needed to reach each level, indexed by level - 1.
List<int> _cumulative(CatalogRecord record) {
  final steps = [...record.progression!.experience]
    ..sort((a, b) => a.fromLevel.compareTo(b.fromLevel));
  final totals = [0];
  for (final step in steps) {
    totals.add(totals.last + step.experience);
  }
  return totals;
}

ProgressionResult calculateProgression(
  CatalogBundle bundle,
  CatalogRecord record,
  ProgressionRules rules,
  ProgressionState from,
  ProgressionState to,
) {
  // Catalogs that carry their own EXP table (genshin-api) need no extra rules.
  final ownTable =
      record.canUseFields(['requirements', 'experience', 'levelCaps']) &&
      record.progression!.maxLevel == 90;
  require(
    ownTable ||
        (ProgressionRules.supported.contains(record.id) &&
            bundle.gameVersion == rules.data['gameVersion']),
    'Este perfil o versión todavía no tiene reglas de progresión verificadas.',
  );
  require(
    record.canUseFields(['requirements']),
    'Los costes del catálogo están pendientes de verificación.',
  );
  final character = record.kind == CatalogKind.character;
  require(
    character ||
        (record.kind == CatalogKind.weapon &&
            [3, 4, 5].contains(record.rarity)),
    'Tipo de progresión no compatible.',
  );
  final xp = ownTable ? _cumulative(record) : rules.table(record);
  void validate(ProgressionState state) {
    require(
      state.ascension >= 0 && state.ascension <= 6,
      'Ascensión válida: 0–6.',
    );
    require(
      state.level >= ProgressionRules.floors[state.ascension] &&
          state.level <= ProgressionRules.caps[state.ascension],
      'El nivel no corresponde a la ascensión elegida.',
    );
    final cap = state.level == ProgressionRules.caps[state.ascension];
    require(
      state.experience >= 0 &&
          (cap
              ? state.experience == 0
              : state.experience < xp[state.level] - xp[state.level - 1]),
      'EXP parcial fuera de rango; en el límite de ascensión debe ser 0.',
    );
    if (character) {
      require(
        state.talents.length == 3 &&
            state.talents.every(
              (v) =>
                  v >= 1 && v <= ProgressionRules.talentCaps[state.ascension],
            ),
        'Talentos base incompatibles con la ascensión. No incluyas bonificaciones de constelación.',
      );
    }
  }

  validate(from);
  validate(to);
  require(
    to.ascension >= from.ascension && to.level >= from.level,
    'El objetivo no puede retroceder.',
  );
  final needed =
      xp[to.level - 1] + to.experience - xp[from.level - 1] - from.experience;
  require(needed >= 0, 'La EXP objetivo es inferior a la actual.');
  final materials = <String, int>{};
  var ascensionMora = 0, talentMora = 0;
  void add(Requirement row) {
    final mora = row.materials['material:202'] ?? 0;
    if (row.kind == 'talent') {
      talentMora += mora;
    } else {
      ascensionMora += mora;
    }
    row.materials.forEach(
      (id, amount) =>
          materials.update(id, (old) => old + amount, ifAbsent: () => amount),
    );
  }

  final rows = record.progression!.requirements;
  for (final row in rows.where(
    (r) =>
        r.kind == 'ascension' &&
        r.stage > from.ascension &&
        r.stage <= to.ascension,
  )) {
    add(row);
  }
  if (character) {
    for (var i = 0; i < 3; i++) {
      require(
        to.talents[i] >= from.talents[i],
        'Los talentos objetivo no pueden retroceder.',
      );
      for (final row in rows.where(
        (r) =>
            r.kind == 'talent' &&
            (r.talentIndex == -1 || r.talentIndex == i) &&
            r.stage > from.talents[i] &&
            r.stage <= to.talents[i],
      )) {
        add(row);
      }
    }
  }
  // Supply only books/ores, rounded independently at each ascension barrier.
  final units = character ? [20000, 5000, 1000] : [10000, 2000, 400];
  final labels = character
      ? [
          'Ingenio del héroe',
          'Experiencia del aventurero',
          'Consejo del errante',
        ]
      : [
          'Mineral de refinamiento místico',
          'Mineral de refinamiento fino',
          'Mineral de refinamiento',
        ];
  final items = <String, int>{};
  var position = xp[from.level - 1] + from.experience;
  final end = xp[to.level - 1] + to.experience;
  var supplied = 0;
  final stops = [
    for (final cap in ProgressionRules.caps)
      if (cap > from.level && cap < to.level) xp[cap - 1],
    end,
  ];
  for (final stop in stops) {
    var remaining = stop - position;
    if (remaining <= 0) continue;
    for (var i = 0; i < units.length; i++) {
      final count = i == units.length - 1
          ? (remaining + units[i] - 1) ~/ units[i]
          : remaining ~/ units[i];
      if (count > 0) {
        items.update(labels[i], (old) => old + count, ifAbsent: () => count);
      }
      supplied += count * units[i];
      remaining -= count * units[i];
    }
    position = stop;
  }
  final mora = supplied ~/ (character ? 5 : 10);
  if (mora > 0) {
    materials.update('material:202', (old) => old + mora, ifAbsent: () => mora);
  }
  return ProgressionResult(
    needed,
    mora,
    Map.unmodifiable(materials),
    Map.unmodifiable(items),
    supplied - needed,
    xpTable: xp,
    fromLevel: from.level,
    toLevel: to.level,
    ascensionMora: ascensionMora,
    talentMora: talentMora,
    startExperience: xp[from.level - 1] + from.experience,
  );
}
