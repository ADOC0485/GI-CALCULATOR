import '../../catalog/data/genshin_api_catalog.dart' show moraId;
import '../../catalog/domain/catalog.dart';
import '../../progression/domain/inventory_plan.dart';
import '../../progression/domain/progression_calculator.dart';

/// What a build levels up.
enum BuildKind {
  character('Solo personaje'),
  weapon('Solo arma'),
  both('Personaje + arma');

  const BuildKind(this.label);
  final String label;
}

/// A character, a weapon or both, with the targets for each. The order of
/// the saved list is the priority: earlier builds get materials first.
class GenshinBuild {
  const GenshinBuild({
    required this.id,
    this.characterId,
    this.characterNow = const ProgressionState(level: 1, ascension: 0),
    this.characterGoal = const ProgressionState(level: 90, ascension: 6),
    this.weaponId,
    this.weaponNow = const ProgressionState(level: 1, ascension: 0),
    this.weaponGoal = const ProgressionState(level: 90, ascension: 6),
    this.talentsOn = true,
    this.finishedAt,
  }) : assert(characterId != null || weaponId != null);
  final String id;
  final String? characterId, weaponId;
  final ProgressionState characterNow, characterGoal, weaponNow, weaponGoal;
  final bool talentsOn;

  /// When it reached its goal (null while in progress).
  final DateTime? finishedAt;

  bool get hasCharacter => characterId != null;
  bool get hasWeapon => weaponId != null;
  bool get finished => finishedAt != null;
  bool get talentsUsed => hasCharacter && talentsOn;

  BuildKind get kind => !hasCharacter
      ? BuildKind.weapon
      : hasWeapon
      ? BuildKind.both
      : BuildKind.character;

  /// "Mavuika + Espada", "Mavuika" or just the weapon's name.
  String name(Map<String, CatalogRecord> byId) => [
    if (characterId != null) byId[characterId]?.name ?? characterId!,
    if (weaponId != null) byId[weaponId]?.name ?? weaponId!,
  ].join(' + ');

  /// Short name used to group its farming tasks: the character's, or the
  /// weapon's when there is no character.
  String owner(Map<String, CatalogRecord> byId) {
    final id = characterId ?? weaponId!;
    return byId[id]?.name ?? id;
  }

  /// True when every part already is where it should end.
  bool get atGoal {
    bool same(ProgressionState a, ProgressionState b) =>
        a.level >= b.level && a.ascension >= b.ascension;
    final characterDone =
        !hasCharacter ||
        (same(characterNow, characterGoal) &&
            (!talentsOn ||
                [
                  for (var i = 0; i < 3; i++)
                    characterNow.talents[i] >= characterGoal.talents[i],
                ].every((v) => v)));
    final weaponDone = !hasWeapon || same(weaponNow, weaponGoal);
    return characterDone && weaponDone;
  }

  GenshinBuild copyWith({
    String? characterId,
    String? weaponId,
    bool clearWeapon = false,
    ProgressionState? characterNow,
    ProgressionState? characterGoal,
    ProgressionState? weaponNow,
    ProgressionState? weaponGoal,
    bool? talentsOn,
    DateTime? finishedAt,
    bool clearFinished = false,
  }) => GenshinBuild(
    id: id,
    characterId: characterId ?? this.characterId,
    weaponId: clearWeapon ? null : weaponId ?? this.weaponId,
    characterNow: characterNow ?? this.characterNow,
    characterGoal: characterGoal ?? this.characterGoal,
    weaponNow: weaponNow ?? this.weaponNow,
    weaponGoal: weaponGoal ?? this.weaponGoal,
    talentsOn: talentsOn ?? this.talentsOn,
    finishedAt: clearFinished ? null : finishedAt ?? this.finishedAt,
  );

  static Map<String, Object?> _state(ProgressionState s) => {
    'level': s.level,
    'ascension': s.ascension,
    'talents': s.talents,
  };

  static ProgressionState _parse(Object? value, ProgressionState fallback) {
    if (value is! Map<String, dynamic>) return fallback;
    return ProgressionState(
      level: value['level'] as int,
      ascension: value['ascension'] as int,
      talents: List<int>.from(value['talents'] as List? ?? const [1, 1, 1]),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'characterId': characterId,
    'weaponId': weaponId,
    'characterNow': _state(characterNow),
    'characterGoal': _state(characterGoal),
    'weaponNow': _state(weaponNow),
    'weaponGoal': _state(weaponGoal),
    'talentsOn': talentsOn,
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
  };

  factory GenshinBuild.fromJson(Map<String, dynamic> json) => GenshinBuild(
    id: json['id'] as String,
    characterId: json['characterId'] as String?,
    weaponId: json['weaponId'] as String?,
    characterNow: _parse(
      json['characterNow'],
      const ProgressionState(level: 1, ascension: 0),
    ),
    characterGoal: _parse(
      json['characterGoal'],
      const ProgressionState(level: 90, ascension: 6),
    ),
    weaponNow: _parse(
      json['weaponNow'],
      const ProgressionState(level: 1, ascension: 0),
    ),
    weaponGoal: _parse(
      json['weaponGoal'],
      const ProgressionState(level: 90, ascension: 6),
    ),
    talentsOn: json['talentsOn'] as bool? ?? true,
    finishedAt: DateTime.tryParse('${json['finishedAt']}'),
  );
}

/// Shared inventory: what the player owns, used by every build.
class Inventory {
  const Inventory({
    this.materials = const {},
    this.characterBooks = const [0, 0, 0],
    this.weaponOres = const [0, 0, 0],
    this.mora = 0,
    this.worldLevel = 8,
    this.adventureRank,
  });
  final Map<String, int> materials;
  final List<int> characterBooks, weaponOres;
  final int mora, worldLevel;
  final int? adventureRank;

  /// How many of [id] the player owns; EXP books, ores and Mora included.
  int owned(String id) {
    for (final (i, item) in characterExpItems.indexed) {
      if (item.id == id) return characterBooks[i];
    }
    for (final (i, item) in weaponExpItems.indexed) {
      if (item.id == id) return weaponOres[i];
    }
    if (id == moraId) return mora;
    return materials[id] ?? 0;
  }

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
  static List<int> _list(Object? v) => v is List
      ? [for (var i = 0; i < 3; i++) i < v.length ? _int(v[i]) : 0]
      : const [0, 0, 0];

  /// Reads the inventory saved by the calculator (text fields).
  factory Inventory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Inventory();
    final materials = json['materials'];
    final rank = int.tryParse('${json['adventureRank']}');
    return Inventory(
      materials: materials is Map
          ? {
              for (final e in materials.entries)
                if (_int(e.value) > 0) '${e.key}': _int(e.value),
            }
          : const {},
      characterBooks: _list(json['booksCharacter']),
      weaponOres: _list(json['booksWeapon']),
      mora: _int(json['mora']),
      worldLevel: int.tryParse('${json['worldLevel']}') ?? 8,
      adventureRank: rank,
    );
  }
}
