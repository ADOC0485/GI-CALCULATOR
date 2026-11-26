import '../../catalog/domain/catalog.dart';
import 'progression_calculator.dart';

class ExpItem {
  const ExpItem(this.label, this.experience, this.id);
  final String label;
  final int experience;

  /// Catalog ID, used to show the item's picture.
  final String id;
}

const characterExpItems = [
  ExpItem('Ingenio del héroe', 20000, 'material:104003'),
  ExpItem('Experiencia del aventurero', 5000, 'material:104002'),
  ExpItem('Consejo del errante', 1000, 'material:104001'),
];
const weaponExpItems = [
  ExpItem('Mineral de refinamiento místico', 10000, 'material:104013'),
  ExpItem('Mineral de refinamiento fino', 2000, 'material:104012'),
  ExpItem('Mineral de refinamiento', 400, 'material:104011'),
];

/// Average ley line yield per 20 Original Resin claim.
///
/// Community tables (gamertagmythras.com world level guide and
/// genshin-guide-one-five.vercel.app ley line guide, November 2026) agree on
/// these averages; they are estimates, not official figures.
class LeyLineRates {
  const LeyLineRates({this.experience = 122500, this.mora = 60000});
  final int experience, mora;
  static const resinPerRun = 20;
  static const _experience = [
    25000,
    38500,
    52500,
    67500,
    82500,
    102500,
    122500,
    122500,
    122500,
    122500,
  ];
  static const _mora = [
    12000,
    20000,
    28000,
    36000,
    44000,
    52000,
    60000,
    60000,
    60000,
    60000,
  ];

  /// Adventure Rank that unlocks each World Level (index = World Level).
  static const unlockRank = [1, 20, 25, 30, 35, 40, 45, 50, 55, 58];
  static const maxWorldLevel = 9;

  factory LeyLineRates.forWorldLevel(int worldLevel) {
    require(
      worldLevel >= 0 && worldLevel <= maxWorldLevel,
      'El nivel de mundo va de 0 a $maxWorldLevel.',
    );
    return LeyLineRates(
      experience: _experience[worldLevel],
      mora: _mora[worldLevel],
    );
  }

  /// Highest World Level an Adventure Rank can have unlocked.
  static int highestFor(int adventureRank) {
    var level = 0;
    for (var w = 0; w <= maxWorldLevel; w++) {
      if (adventureRank >= unlockRank[w]) level = w;
    }
    return level;
  }

  /// World Levels gated by an ascension quest: until it is done, the AR
  /// stays capped at the unlock rank (World Level 9 does not cap the AR).
  static const _questLevels = {2, 4, 6, 7, 9};

  /// Lowest World Level the account surely has at [adventureRank]: reaching
  /// a higher AR proves every earlier ascension quest was completed.
  static int guaranteedFor(int adventureRank) {
    final highest = highestFor(adventureRank);
    return _questLevels.contains(highest) &&
            adventureRank == unlockRank[highest]
        ? highest - 1
        : highest == maxWorldLevel
        ? highest - 1
        : highest;
  }

  /// Checks a World Level against the Adventure Rank. The game lets players
  /// lower their World Level by one, so anything below that is impossible.
  /// Returns a hint when the level was lowered.
  static String? checkAccount(int worldLevel, int adventureRank) {
    require(
      adventureRank >= 1 && adventureRank <= 60,
      'El rango de aventura (AR) va de 1 a 60.',
    );
    final highest = highestFor(adventureRank);
    final lowest = (guaranteedFor(adventureRank) - 1).clamp(0, highest);
    require(
      worldLevel <= highest,
      'Con AR $adventureRank el nivel de mundo máximo es $highest. Revisa ambos datos.',
    );
    require(
      worldLevel >= lowest,
      'Con AR $adventureRank tu nivel de mundo es al menos $lowest '
      '(el juego solo deja bajarlo un nivel). Revisa ambos datos.',
    );
    if (worldLevel < guaranteedFor(adventureRank)) {
      return 'Nivel de mundo bajado: las líneas ley se calculan con el $worldLevel.';
    }
    return null;
  }
}

class MaterialLine {
  const MaterialLine(this.id, this.needed, this.owned, this.crafted);
  final String id;
  final int needed, owned;

  /// Units of this item made by alchemy from the lower tier.
  final int crafted;
  int get missing => (needed - owned - crafted).clamp(0, needed);
}

class InventoryPlan {
  InventoryPlan({
    required this.expNeeded,
    required this.expOwned,
    required this.levelWithOwned,
    required this.booksToFarm,
    required this.expRuns,
    required this.moraNeeded,
    required this.moraOwned,
    required this.craftingMora,
    required this.moraRuns,
    required this.lines,
    this.used = const {},
  });
  final int expNeeded, expOwned, levelWithOwned, expRuns;
  final Map<String, int> booksToFarm;
  final int moraNeeded, moraOwned, craftingMora, moraRuns;
  final List<MaterialLine> lines;

  /// Units taken from the owned materials, by id: what is used directly plus
  /// what goes into crafting, lower tiers that are not needed included.
  final Map<String, int> used;
  int get expMissing => (expNeeded - expOwned).clamp(0, expNeeded);
  int get moraTotal => moraNeeded + craftingMora;
  int get moraMissing => (moraTotal - moraOwned).clamp(0, moraTotal);
}

/// Mora uses its game ID in both the seed and the online catalog.
const _mora = 'material:202';

int _ceilDiv(int a, int b) => a <= 0 ? 0 : (a + b - 1) ~/ b;

/// Compares a progression result with what the player already owns.
///
/// [ownedBooks] follows the order of [characterExpItems] / [weaponExpItems].
/// Lower tiers are crafted 3→1 only as far as higher tiers still need them,
/// even when the build itself does not need the lower tier (for example
/// spare Teachings and Guides turned into the Philosophies a talent needs).
InventoryPlan planInventory({
  required CatalogBundle bundle,
  required CatalogRecord record,
  required ProgressionResult result,
  required List<int> ownedBooks,
  required Map<String, int> ownedMaterials,
  int ownedMora = 0,
  LeyLineRates rates = const LeyLineRates(),
}) {
  require(
    rates.experience > 0 && rates.mora > 0,
    'El rendimiento de las líneas ley debe ser mayor que 0.',
  );
  final character = record.kind == CatalogKind.character;
  final items = character ? characterExpItems : weaponExpItems;
  var expOwned = 0;
  for (var i = 0; i < items.length; i++) {
    expOwned +=
        items[i].experience * (i < ownedBooks.length ? ownedBooks[i] : 0);
  }
  final expMissing = (result.experience - expOwned).clamp(0, result.experience);
  final books = <String, int>{};
  var remaining = expMissing;
  for (var i = 0; i < items.length; i++) {
    final count = i == items.length - 1
        ? _ceilDiv(remaining, items[i].experience)
        : remaining ~/ items[i].experience;
    if (count > 0) books[items[i].label] = count;
    remaining -= count * items[i].experience;
  }

  final recipes = <String, CraftRecipe>{
    for (final r in bundle.records)
      if (r.material?.craft != null) r.id: r.material!.craft!,
  };
  final parentOf = {for (final e in recipes.entries) e.value.fromId: e.key};
  final needed = {
    for (final e in result.materials.entries)
      if (e.key != _mora) e.key: e.value,
  };
  // Every needed item and the lower tiers it can be crafted from.
  final family = <String>{};
  for (final id in needed.keys) {
    for (String? c = id; c != null && family.add(c); c = recipes[c]?.fromId) {}
  }
  int owned(String id) => ownedMaterials[id] ?? 0;
  int need(String id) => needed[id] ?? 0;

  // Units of [id] still required for itself and every tier above it.
  int upDemand(String id) {
    final parent = parentOf[id];
    final above = parent == null || !family.contains(parent)
        ? 0
        : recipes[parent]!.quantity * upDemand(parent);
    return (need(id) + above - owned(id)).clamp(0, 1 << 40);
  }

  int depth(String id) {
    var d = 0;
    for (var c = recipes[id]; c != null; c = recipes[c.fromId]) {
      d++;
    }
    return d;
  }

  final made = <String, int>{};
  final inputs = <String, int>{};
  var craftingMora = 0;
  final order = family.toList()..sort((a, b) => depth(a).compareTo(depth(b)));
  for (final id in order) {
    final parent = parentOf[id];
    if (parent == null || !family.contains(parent)) continue;
    final available = owned(id) + (made[id] ?? 0);
    final spare = available - need(id);
    final recipe = recipes[parent]!;
    if (spare < recipe.quantity) continue;
    final parentShort = upDemand(parent) - (made[parent] ?? 0);
    final count = [
      spare ~/ recipe.quantity,
      parentShort,
    ].reduce((a, b) => a < b ? a : b);
    if (count <= 0) continue;
    made[parent] = (made[parent] ?? 0) + count;
    inputs[id] = count * recipe.quantity;
    craftingMora += count * recipe.mora;
  }

  final mora = result.materials[_mora] ?? 0;
  return InventoryPlan(
    expNeeded: result.experience,
    expOwned: expOwned,
    levelWithOwned: result.levelWith(expOwned),
    booksToFarm: books,
    expRuns: character ? _ceilDiv(expMissing, rates.experience) : 0,
    moraNeeded: mora,
    moraOwned: ownedMora,
    craftingMora: craftingMora,
    moraRuns: _ceilDiv(mora + craftingMora - ownedMora, rates.mora),
    lines: [
      for (final id in _displayOrder(bundle, character, needed.keys, recipes))
        MaterialLine(
          id,
          needed[id]!,
          owned(id).clamp(0, needed[id]!),
          (made[id] ?? 0).clamp(
            0,
            (needed[id]! - owned(id)).clamp(0, needed[id]!),
          ),
        ),
    ],
    used: {
      for (final id in family)
        if ((need(id) + (inputs[id] ?? 0)).clamp(0, owned(id)) case final n
            when n > 0)
          id: n,
    },
  );
}

/// Order in which materials are listed, by category, as the game groups them.
const _characterOrder = [
  'Especialidad local',
  'Material de jefe',
  'Gema de ascensión',
  'Botín común',
  'Libro de talento',
  'Material de jefe semanal',
];
const _weaponOrder = ['Material de ascensión de arma', 'Botín común'];

/// Sorts materials by category; each crafting family stays together from the
/// lowest tier to the highest, and loose items (like the crown) go last.
List<String> _displayOrder(
  CatalogBundle bundle,
  bool character,
  Iterable<String> ids,
  Map<String, CraftRecipe> recipes,
) {
  final categories = {
    for (final r in bundle.records)
      if (r.material != null) r.id: r.material!.category,
  };
  final order = character ? _characterOrder : _weaponOrder;
  String root(String id) {
    var current = id;
    while (recipes[current] != null) {
      current = recipes[current]!.fromId;
    }
    return current;
  }

  int depth(String id) {
    var d = 0;
    for (var c = recipes[id]; c != null; c = recipes[c.fromId]) {
      d++;
    }
    return d;
  }

  final list = ids.toList();
  final familySize = <String, int>{};
  for (final id in list) {
    familySize.update(root(id), (n) => n + 1, ifAbsent: () => 1);
  }
  int rank(String id) {
    final category = categories[id] ?? '';
    // The Crown of Insight is filed as a talent book: list it last.
    if (category == 'Libro de talento' && familySize[root(id)] == 1) {
      return order.length;
    }
    final index = order.indexOf(category);
    return index < 0 ? order.length + 1 : index;
  }

  final position = {for (final (i, id) in list.indexed) id: i};
  list.sort((a, b) {
    for (final c in [
      rank(a).compareTo(rank(b)),
      (familySize[root(a)]! > 1 ? 0 : 1).compareTo(
        familySize[root(b)]! > 1 ? 0 : 1,
      ),
      position[root(a)]?.compareTo(position[root(b)] ?? 0) ??
          root(a).compareTo(root(b)),
      depth(a).compareTo(depth(b)),
      position[a]!.compareTo(position[b]!),
    ]) {
      if (c != 0) return c;
    }
    return 0;
  });
  return list;
}
