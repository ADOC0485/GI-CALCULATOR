import '../../progression/domain/progression_calculator.dart';

/// A character with their weapon and the targets for both.
class GenshinBuild {
  const GenshinBuild({
    required this.id,
    required this.characterId,
    required this.characterNow,
    required this.characterGoal,
    this.weaponId,
    this.weaponNow = const ProgressionState(level: 1, ascension: 0),
    this.weaponGoal = const ProgressionState(level: 90, ascension: 6),
    this.talentsOn = true,
  });
  final String id, characterId;
  final String? weaponId;
  final ProgressionState characterNow, characterGoal, weaponNow, weaponGoal;
  final bool talentsOn;

  GenshinBuild copyWith({
    String? characterId,
    String? weaponId,
    bool clearWeapon = false,
    ProgressionState? characterNow,
    ProgressionState? characterGoal,
    ProgressionState? weaponNow,
    ProgressionState? weaponGoal,
    bool? talentsOn,
  }) => GenshinBuild(
    id: id,
    characterId: characterId ?? this.characterId,
    weaponId: clearWeapon ? null : weaponId ?? this.weaponId,
    characterNow: characterNow ?? this.characterNow,
    characterGoal: characterGoal ?? this.characterGoal,
    weaponNow: weaponNow ?? this.weaponNow,
    weaponGoal: weaponGoal ?? this.weaponGoal,
    talentsOn: talentsOn ?? this.talentsOn,
  );

  static Map<String, Object?> _state(ProgressionState s) => {
    'level': s.level,
    'ascension': s.ascension,
    'talents': s.talents,
  };

  static ProgressionState _parse(Object? value) {
    final json = value as Map<String, dynamic>;
    return ProgressionState(
      level: json['level'] as int,
      ascension: json['ascension'] as int,
      talents: List<int>.from(json['talents'] as List? ?? const [1, 1, 1]),
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
  };

  factory GenshinBuild.fromJson(Map<String, dynamic> json) => GenshinBuild(
    id: json['id'] as String,
    characterId: json['characterId'] as String,
    weaponId: json['weaponId'] as String?,
    characterNow: _parse(json['characterNow']),
    characterGoal: _parse(json['characterGoal']),
    weaponNow: _parse(json['weaponNow']),
    weaponGoal: _parse(json['weaponGoal']),
    talentsOn: json['talentsOn'] as bool? ?? true,
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
