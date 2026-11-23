import '../../catalog/domain/catalog.dart';
import 'progression_calculator.dart';

class ExpItem {
  const ExpItem(this.label, this.experience);
  final String label;
  final int experience;
}

const characterExpItems = [
  ExpItem('Ingenio del héroe', 20000),
  ExpItem('Experiencia del aventurero', 5000),
  ExpItem('Consejo del errante', 1000),
];
const weaponExpItems = [
  ExpItem('Mineral de refinamiento místico', 10000),
  ExpItem('Mineral de refinamiento fino', 2000),
  ExpItem('Mineral de refinamiento', 400),
];

/// Average ley line yield per 20 Original Resin; the user can adjust both.
/// Default EXP: 420 resin give 126 Hero's Wit at World Level 6–8, so
/// 6 Hero's Wit (120 000 EXP) per claim.
class LeyLineRates {
  const LeyLineRates({this.experience = 120000, this.mora = 60000});
  final int experience, mora;
  static const resinPerRun = 20;
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
  });
  final int expNeeded, expOwned, levelWithOwned, expRuns;
  final Map<String, int> booksToFarm;
  final int moraNeeded, moraOwned, craftingMora, moraRuns;
  final List<MaterialLine> lines;
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
/// Lower tiers are crafted 3→1 only as far as higher tiers still need them.
InventoryPlan planInventory({
  required CatalogBundle bundle,
  required CatalogRecord record,
  required ProgressionResult result,
  required List<int> ownedBooks,
  required Map<String, int> ownedMaterials,
  int ownedMora = 0,
  LeyLineRates rates = const LeyLineRates(),
}) {
  require(rates.experience > 0 && rates.mora > 0, 'El rendimiento de las líneas ley debe ser mayor que 0.');
  final character = record.kind == CatalogKind.character;
  final items = character ? characterExpItems : weaponExpItems;
  var expOwned = 0;
  for (var i = 0; i < items.length; i++) {
    expOwned += items[i].experience * (i < ownedBooks.length ? ownedBooks[i] : 0);
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
  int owned(String id) => ownedMaterials[id] ?? 0;
  int need(String id) => needed[id] ?? 0;

  // Units of [id] still required for itself and every tier above it.
  int upDemand(String id) {
    final parent = parentOf[id];
    final above = parent == null || !needed.containsKey(parent)
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
  var craftingMora = 0;
  final order = needed.keys.toList()
    ..sort((a, b) => depth(a).compareTo(depth(b)));
  for (final id in order) {
    final parent = parentOf[id];
    if (parent == null || !needed.containsKey(parent)) continue;
    final available = owned(id) + (made[id] ?? 0);
    final spare = available - need(id);
    final recipe = recipes[parent]!;
    if (spare < recipe.quantity) continue;
    final parentShort = upDemand(parent) - (made[parent] ?? 0);
    final count = [spare ~/ recipe.quantity, parentShort].reduce(
      (a, b) => a < b ? a : b,
    );
    if (count <= 0) continue;
    made[parent] = (made[parent] ?? 0) + count;
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
      for (final e in needed.entries)
        MaterialLine(
          e.key,
          e.value,
          owned(e.key).clamp(0, e.value),
          (made[e.key] ?? 0).clamp(0, (e.value - owned(e.key)).clamp(0, e.value)),
        ),
    ],
  );
}

