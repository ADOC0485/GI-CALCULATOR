import '../../catalog/domain/catalog.dart';
import '../../progression/domain/progression_calculator.dart';
import 'build.dart';
import 'resin_planner.dart';

/// How the shared inventory is split among the builds in progress: each one
/// takes what it needs in priority order (the first build takes first).
class Reservations {
  const Reservations(this.byBuild, this.freeBefore, this.left);

  /// Units of each item set aside for each build, by build id.
  final Map<String, Map<String, int>> byBuild;

  /// What is still free for each build after the ones above it, by build id.
  final Map<String, InventoryPool> freeBefore;

  /// What no build in progress needs.
  final InventoryPool left;

  /// Who holds [itemId], in priority order, as (build id, units).
  List<(String, int)> holders(String itemId) => [
    for (final e in byBuild.entries)
      if ((e.value[itemId] ?? 0) > 0) (e.key, e.value[itemId]!),
  ];
}

Reservations reserveInventory({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required List<GenshinBuild> builds,
  required Inventory inventory,
}) {
  final pool = InventoryPool(inventory);
  final byBuild = <String, Map<String, int>>{};
  final freeBefore = <String, InventoryPool>{};
  for (final build in builds) {
    freeBefore[build.id] = InventoryPool.copy(pool);
    final before = pool.snapshot();
    try {
      buildNeedsFromPool(
        bundle: bundle,
        rules: rules,
        build: build,
        pool: pool,
      );
    } on CalculationException {
      // A broken build reserves nothing; its page explains the problem.
    }
    byBuild[build.id] = pool.usedSince(before);
  }
  return Reservations(byBuild, freeBefore, pool);
}

/// Where a build ends after leveling it up now.
class StepTarget {
  const StepTarget({this.character, this.weapon});
  final ProgressionState? character, weapon;

  GenshinBuild applyTo(GenshinBuild build) =>
      build.copyWith(characterNow: character, weaponNow: weapon);
}

/// Whether [build] can go to [target] with what [pool] holds.
bool _fits(
  CatalogBundle bundle,
  ProgressionRules rules,
  GenshinBuild build,
  StepTarget target,
  InventoryPool pool,
) {
  try {
    final phases = buildNeedsFromPool(
      bundle: bundle,
      rules: rules,
      build: _stepBuild(build, target),
      pool: InventoryPool.copy(pool),
    );
    return phases.every((p) => p.done);
  } on CalculationException {
    return false;
  }
}

/// The step as a build of its own: from where it is now to [target].
GenshinBuild _stepBuild(GenshinBuild build, StepTarget target) => GenshinBuild(
  id: 'paso',
  characterId: build.characterId,
  weaponId: build.weaponId,
  characterNow: build.characterNow,
  characterGoal: target.character ?? build.characterNow,
  weaponNow: build.weaponNow,
  weaponGoal: target.weapon ?? build.weaponNow,
  talentsOn: build.talentsOn,
);

/// Every (level, ascension) between [now] and [goal], in game order:
/// 50/50 comes before 50/60.
List<ProgressionState> _path(ProgressionState now, ProgressionState goal) => [
  for (var a = now.ascension; a <= goal.ascension; a++)
    for (
      var level = a == now.ascension
          ? now.level
          : ProgressionRules.floors[a].clamp(now.level, 90);
      level <= ProgressionRules.caps[a] && level <= goal.level;
      level++
    )
      if (!(a == now.ascension && level == now.level))
        ProgressionState(level: level, ascension: a, talents: now.talents),
];

/// The furthest a build can go with [pool]: first the character's level,
/// then the weapon, then the talents a little at a time.
StepTarget suggestStep({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required GenshinBuild build,
  required InventoryPool pool,
}) {
  var target = StepTarget(
    character: build.hasCharacter ? build.characterNow : null,
    weapon: build.hasWeapon ? build.weaponNow : null,
  );
  bool fits(StepTarget t) => _fits(bundle, rules, build, t, pool);
  if (build.hasCharacter) {
    for (final s in _path(build.characterNow, build.characterGoal)) {
      final next = StepTarget(character: s, weapon: target.weapon);
      if (!fits(next)) break;
      target = next;
    }
  }
  if (build.hasWeapon) {
    for (final s in _path(build.weaponNow, build.weaponGoal)) {
      final next = StepTarget(character: target.character, weapon: s);
      if (!fits(next)) break;
      target = next;
    }
  }
  if (build.talentsUsed) {
    final c = target.character!;
    final cap = ProgressionRules.talentCaps[c.ascension];
    final talents = [...c.talents];
    var grew = true;
    while (grew) {
      grew = false;
      for (var i = 0; i < 3; i++) {
        if (talents[i] >= build.characterGoal.talents[i] || talents[i] >= cap) {
          continue;
        }
        final tried = [...talents]..[i] += 1;
        final next = StepTarget(
          character: ProgressionState(
            level: c.level,
            ascension: c.ascension,
            talents: tried,
          ),
          weapon: target.weapon,
        );
        if (fits(next)) {
          talents[i] += 1;
          target = next;
          grew = true;
        }
      }
    }
  }
  return target;
}

/// What leveling up costs and whose reservation it touches.
class StepCheck {
  const StepCheck({
    required this.used,
    required this.short,
    required this.takenFrom,
  });

  /// Units taken from the inventory, by item id.
  final Map<String, int> used;

  /// Units the inventory does not have even counting everything.
  final Map<String, int> short;

  /// Reserved items it takes from builds with more priority:
  /// build id → item id → units.
  final Map<String, Map<String, int>> takenFrom;

  bool get nothing => used.isEmpty;
}

StepCheck checkStep({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required GenshinBuild build,
  required StepTarget target,
  required Inventory inventory,
  required List<GenshinBuild> builds,
}) {
  final step = _stepBuild(build, target);
  final pool = InventoryPool(inventory);
  final before = pool.snapshot();
  final phases = buildNeedsFromPool(
    bundle: bundle,
    rules: rules,
    build: step,
    pool: pool,
  );
  final used = pool.usedSince(before);
  final short = <String, int>{};
  for (final p in phases) {
    for (final line in p.plan.lines) {
      if (line.missing > 0) {
        short.update(
          line.id,
          (v) => v + line.missing,
          ifAbsent: () => line.missing,
        );
      }
    }
    if (p.plan.moraMissing > 0) {
      short.update(
        'material:202',
        (v) => v + p.plan.moraMissing,
        ifAbsent: () => p.plan.moraMissing,
      );
    }
    if (p.plan.expMissing > 0) {
      short.update(
        'exp',
        (v) => v + p.plan.expMissing,
        ifAbsent: () => p.plan.expMissing,
      );
    }
  }

  // Items the step takes beyond what the builds above left free.
  final index = builds.indexWhere((b) => b.id == build.id);
  final above = index < 0 ? builds : builds.sublist(0, index);
  final reservations = reserveInventory(
    bundle: bundle,
    rules: rules,
    builds: above,
    inventory: inventory,
  );
  final freeCounts = reservations.left.snapshot();
  final takenFrom = <String, Map<String, int>>{};
  for (final e in used.entries) {
    var over = e.value - (freeCounts[e.key] ?? 0);
    // Taken from the lowest priority build above first.
    for (final b in above.reversed) {
      if (over <= 0) break;
      final held = reservations.byBuild[b.id]?[e.key] ?? 0;
      final take = held < over ? held : over;
      if (take > 0) {
        takenFrom.putIfAbsent(b.id, () => {})[e.key] = take;
        over -= take;
      }
    }
  }
  return StepCheck(used: used, short: short, takenFrom: takenFrom);
}
