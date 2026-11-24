import '../../catalog/domain/catalog.dart';
import '../../progression/domain/inventory_plan.dart';
import '../../progression/domain/progression_calculator.dart';
import 'build.dart';

/// Order in which a build is completed.
enum BuildPhase {
  characterLevel('Subir personaje'),
  weaponLevel('Subir arma'),
  talents('Subir talentos');

  const BuildPhase(this.label);
  final String label;
}

class PhaseNeeds {
  const PhaseNeeds(this.phase, this.record, this.result, this.plan);
  final BuildPhase phase;
  final CatalogRecord record;
  final ProgressionResult result;
  final InventoryPlan plan;
  bool get done =>
      plan.expMissing == 0 &&
      plan.moraMissing == 0 &&
      plan.lines.every((l) => l.missing == 0);
}

/// What is still unassigned while several builds take from one inventory.
class InventoryPool {
  InventoryPool(Inventory inventory)
    : materials = Map.of(inventory.materials),
      books = List.of(inventory.characterBooks),
      ores = List.of(inventory.weaponOres),
      mora = inventory.mora,
      worldLevel = inventory.worldLevel;
  final Map<String, int> materials;
  final List<int> books, ores;
  int mora;
  final int worldLevel;

  /// Takes the EXP items a phase uses: big ones first, small ones to finish.
  static void consume(List<int> owned, List<ExpItem> items, int experience) {
    var left = experience;
    for (var i = 0; i < items.length && left > 0; i++) {
      final use = (left ~/ items[i].experience).clamp(0, owned[i]);
      owned[i] -= use;
      left -= use * items[i].experience;
    }
    for (var i = items.length - 1; i >= 0 && left > 0; i--) {
      final use = ((left + items[i].experience - 1) ~/ items[i].experience)
          .clamp(0, owned[i]);
      owned[i] -= use;
      left -= use * items[i].experience;
    }
  }
}

/// Splits a build into phases and hands the shared inventory to them in
/// priority order, so what you own goes to the first phase that needs it.
List<PhaseNeeds> buildNeeds({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required GenshinBuild build,
  required Inventory inventory,
}) => buildNeedsFromPool(
  bundle: bundle,
  rules: rules,
  build: build,
  pool: InventoryPool(inventory),
);

/// Like [buildNeeds], but takes from (and updates) a pool shared by builds.
List<PhaseNeeds> buildNeedsFromPool({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required GenshinBuild build,
  required InventoryPool pool,
}) {
  final byId = {for (final r in bundle.records) r.id: r};
  final character = byId[build.characterId];
  require(character != null, 'El personaje ya no está en el catálogo.');
  final weapon = build.weaponId == null ? null : byId[build.weaponId];
  final owned = pool.materials;
  final rates = LeyLineRates.forWorldLevel(pool.worldLevel);
  final phases = <PhaseNeeds>[];

  void add(
    BuildPhase phase,
    CatalogRecord record,
    ProgressionState from,
    ProgressionState to,
    List<int> books,
  ) {
    final result = calculateProgression(bundle, record, rules, from, to);
    final plan = planInventory(
      bundle: bundle,
      record: record,
      result: result,
      ownedBooks: books,
      ownedMaterials: {
        for (final id in result.materials.keys) id: owned[id] ?? 0,
      },
      ownedMora: pool.mora,
      rates: rates,
    );
    for (final line in plan.lines) {
      final used = (owned[line.id] ?? 0).clamp(0, line.needed);
      owned[line.id] = (owned[line.id] ?? 0) - used;
      final recipe = byId[line.id]?.material?.craft;
      if (line.crafted > 0 && recipe != null) {
        owned[recipe.fromId] =
            ((owned[recipe.fromId] ?? 0) - line.crafted * recipe.quantity)
                .clamp(0, 1 << 40);
      }
    }
    pool.mora = (pool.mora - plan.moraTotal).clamp(0, pool.mora);
    if (identical(books, pool.books)) {
      InventoryPool.consume(pool.books, characterExpItems, result.experience);
    } else if (identical(books, pool.ores)) {
      InventoryPool.consume(pool.ores, weaponExpItems, result.experience);
    }
    phases.add(PhaseNeeds(phase, record, result, plan));
  }

  final now = build.characterNow, goal = build.characterGoal;
  add(
    BuildPhase.characterLevel,
    character!,
    ProgressionState(
      level: now.level,
      ascension: now.ascension,
      talents: now.talents,
    ),
    ProgressionState(
      level: goal.level,
      ascension: goal.ascension,
      talents: now.talents,
    ),
    pool.books,
  );
  if (weapon != null) {
    add(
      BuildPhase.weaponLevel,
      weapon,
      build.weaponNow,
      build.weaponGoal,
      pool.ores,
    );
  }
  if (build.talentsOn) {
    add(
      BuildPhase.talents,
      character,
      ProgressionState(
        level: goal.level,
        ascension: goal.ascension,
        talents: now.talents,
      ),
      goal,
      const [0, 0, 0],
    );
  }
  return phases;
}

enum TaskKind {
  weeklyBoss('Jefe semanal'),
  talentDomain('Dominio de talentos'),
  weaponDomain('Dominio de armas'),
  worldBoss('Jefe de mundo'),
  expLeyLine('Línea ley de EXP'),
  moraLeyLine('Línea ley de Mora');

  const TaskKind(this.label);
  final String label;
}

/// Community averages per claim at the highest World Level (gamerant.com
/// drop-rate tables and news.bittopup.com loot scaling guide agree on them).
class DropAverages {
  static const bossMaterial = 2.55;

  /// Gems per world boss claim, in sliver units (2.15 + 3×1.60 + 9×0.14 + 27×0.014).
  static const gemUnits = 2.15 + 3 * 1.60 + 9 * 0.14 + 27 * 0.014;
  static const weeklyMaterial = 2.39;

  /// Talent books per domain claim, in green units (2.20 + 3×1.97 + 9×0.23).
  static const bookUnits = 2.20 + 3 * 1.97 + 9 * 0.23;

  /// Weapon materials per domain claim, in green units.
  static const weaponUnits = 2.20 + 3 * 2.40 + 9 * 0.64 + 27 * 0.07;
}

class FarmTask {
  FarmTask({
    required this.kind,
    required this.phase,
    required this.title,
    required this.runs,
    required this.resin,
    this.materialId,
    this.days = const {},
    this.group = 0,
    this.owner = '',
    this.bossKey,
    this.materialIds = const [],
  });
  final TaskKind kind;

  /// What the task gives, asked for when it is checked (lowest tier first).
  final List<String> materialIds;
  final BuildPhase phase;
  final String title;

  /// Lower groups are farmed first (build order, then phase).
  final int group;

  /// Name of the build the task belongs to (empty for a single build).
  final String owner;

  /// Weekly bosses are claimed once per week each, whatever the build.
  final String? bossKey;
  final int runs, resin;
  final String? materialId;

  /// Weekdays (1 = Monday) when it can be done; empty means every day.
  final Set<int> days;
  int remaining = 0;
}

/// Something to collect without resin (specialties, enemy drops, crowns…).
class FreeTask {
  const FreeTask(
    this.title,
    this.materialId,
    this.missing, [
    this.materialIds = const [],
  ]);
  final String title;
  final String? materialId;
  final int missing;

  /// What collecting it gives, asked for when it is checked.
  final List<String> materialIds;
}

/// A material and the ones crafted from it or into it, lowest tier first.
List<String> craftFamily(Map<String, CatalogRecord> byId, String id) {
  var base = id;
  final seen = <String>{};
  while (seen.add(base)) {
    final from = byId[base]?.material?.craft?.fromId;
    if (from == null) break;
    base = from;
  }
  final up = <String, String>{
    for (final r in byId.values)
      if (r.material?.craft case final craft?) craft.fromId: r.id,
  };
  final family = [base];
  for (
    var next = up[base];
    next != null && !family.contains(next);
    next = up[next]
  ) {
    family.add(next);
  }
  return family;
}

class FarmPlan {
  const FarmPlan(this.tasks, this.free);
  final List<FarmTask> tasks;
  final List<FreeTask> free;
}

int _ceil(double v) => v <= 0 ? 0 : v.ceil();

/// Turns what is missing into resin activities and free tasks.
FarmPlan farmTasks({
  required CatalogBundle bundle,
  required List<PhaseNeeds> phases,
  required LeyLineRates rates,
  int groupBase = 0,
  String owner = '',
}) {
  final byId = {for (final r in bundle.records) r.id: r};
  final tasks = <FarmTask>[];
  final free = <FreeTask>[];
  String name(String id) => byId[id]?.name ?? id;
  String? category(String id) => byId[id]?.material?.category;
  int depth(String id) {
    var d = 0;
    for (
      var c = byId[id]?.material?.craft;
      c != null;
      c = byId[c.fromId]?.material?.craft
    ) {
      d++;
    }
    return d;
  }

  int units(Iterable<MaterialLine> lines) {
    var total = 0;
    for (final l in lines) {
      var factor = 1;
      for (var i = 0; i < depth(l.id); i++) {
        factor *= 3;
      }
      total += l.missing * factor;
    }
    return total;
  }

  Set<int> daysOf(Iterable<MaterialLine> lines) => {
    for (final l in lines)
      for (final a in byId[l.id]?.activityIds ?? const <String>[])
        ...?byId[a]?.activity?.days,
  };

  for (final need in phases) {
    final missing = need.plan.lines.where((l) => l.missing > 0).toList();
    final phase = need.phase;
    final crafted = {
      for (final l in missing) ?byId[l.id]?.material?.craft?.fromId,
    };
    Iterable<MaterialLine> of(String cat) =>
        missing.where((l) => category(l.id) == cat);

    final boss = of('Material de jefe').toList();
    final gems = of('Gema de ascensión').toList();
    if (boss.isNotEmpty || gems.isNotEmpty) {
      final runs = [
        _ceil(
          boss.fold(0, (s, l) => s + l.missing) / DropAverages.bossMaterial,
        ),
        _ceil(units(gems) / DropAverages.gemUnits),
      ].reduce((a, b) => a > b ? a : b);
      final icon = boss.isNotEmpty ? boss.first.id : gems.first.id;
      tasks.add(
        FarmTask(
          kind: TaskKind.worldBoss,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: boss.isNotEmpty
              ? 'Jefe de mundo: ${name(icon)} y gemas'
              : 'Jefe de mundo del elemento: ${name(icon)}',
          runs: runs,
          resin: 40,
          materialId: icon,
          materialIds: [
            for (final l in boss) l.id,
            if (gems.isNotEmpty) ...craftFamily(byId, gems.first.id),
          ],
        ),
      );
    }
    for (final l in of('Material de jefe semanal')) {
      tasks.add(
        FarmTask(
          kind: TaskKind.weeklyBoss,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: 'Jefe semanal: ${name(l.id)}',
          bossKey:
              byId[l.id]?.material?.sourceHints
                  .where((h) => h.startsWith('Lo sueltan'))
                  .firstOrNull ??
              l.id,
          runs: _ceil(l.missing / DropAverages.weeklyMaterial),
          resin: 30,
          materialId: l.id,
          materialIds: [l.id],
        ),
      );
    }
    final books = of('Libro de talento').toList();
    // Items that neither craft nor are crafted (the crown) cannot be farmed.
    final chain = books
        .where(
          (l) => byId[l.id]?.material?.craft != null || crafted.contains(l.id),
        )
        .toList();
    if (chain.isNotEmpty) {
      tasks.add(
        FarmTask(
          kind: TaskKind.talentDomain,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: 'Dominio de talentos: ${name(chain.first.id)}',
          runs: _ceil(units(chain) / DropAverages.bookUnits),
          resin: 20,
          materialId: chain.first.id,
          materialIds: craftFamily(byId, chain.first.id),
          days: daysOf(books),
        ),
      );
    }
    for (final l in books.where((l) => !chain.contains(l))) {
      free.add(
        FreeTask(
          '${name(l.id)}: sale en eventos y ofrendas de reputación',
          l.id,
          l.missing,
          [l.id],
        ),
      );
    }
    final weaponMats = of('Material de ascensión de arma').toList();
    if (weaponMats.isNotEmpty) {
      tasks.add(
        FarmTask(
          kind: TaskKind.weaponDomain,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: 'Dominio de armas: ${name(weaponMats.first.id)}',
          runs: _ceil(units(weaponMats) / DropAverages.weaponUnits),
          resin: 20,
          materialId: weaponMats.first.id,
          materialIds: craftFamily(byId, weaponMats.first.id),
          days: daysOf(weaponMats),
        ),
      );
    }
    const handled = {
      'Material de jefe',
      'Gema de ascensión',
      'Material de jefe semanal',
      'Libro de talento',
      'Material de ascensión de arma',
    };
    for (final l in missing.where((l) => !handled.contains(category(l.id)))) {
      final cat = category(l.id);
      free.add(
        FreeTask(
          cat == 'Especialidad local'
              ? '${name(l.id)}: recógela en el mapa (reaparece cada 2 días)'
              : cat == 'Botín común'
              ? '${name(l.id)}: derrota enemigos que la suelten'
              : name(l.id),
          l.id,
          l.missing,
          craftFamily(byId, l.id),
        ),
      );
    }
    if (phase == BuildPhase.characterLevel && need.plan.expMissing > 0) {
      tasks.add(
        FarmTask(
          kind: TaskKind.expLeyLine,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: 'Línea ley de EXP (libros de personaje)',
          runs: _ceil(need.plan.expMissing / rates.experience),
          resin: 20,
          materialId: 'material:104003',
          materialIds: [for (final e in characterExpItems.reversed) e.id],
        ),
      );
    }
    if (phase == BuildPhase.weaponLevel && need.plan.expMissing > 0) {
      free.add(
        FreeTask(
          'Mineral de refinamiento místico: forja, minería y cofres',
          'material:104013',
          _ceil(need.plan.expMissing / 10000),
          [for (final e in weaponExpItems.reversed) e.id],
        ),
      );
    }
    if (need.plan.moraMissing > 0) {
      tasks.add(
        FarmTask(
          kind: TaskKind.moraLeyLine,
          phase: phase,
          group: groupBase + phase.index,
          owner: owner,
          title: 'Línea ley de Mora',
          runs: _ceil(need.plan.moraMissing / rates.mora),
          resin: 20,
          materialId: 'material:202',
          materialIds: const ['material:202'],
        ),
      );
    }
  }
  // The same drop can be needed by several phases: list it once.
  final merged = <String, FreeTask>{};
  for (final f in free) {
    final key = f.materialId ?? f.title;
    final old = merged[key];
    merged[key] = old == null
        ? f
        : FreeTask(
            old.title,
            old.materialId,
            old.missing + f.missing,
            old.materialIds,
          );
  }
  return FarmPlan(
    tasks.where((t) => t.runs > 0).toList(),
    merged.values.toList(),
  );
}

class PlannedRun {
  const PlannedRun(this.task, this.count, this.resin, [this.condensed = 0]);
  final FarmTask task;
  final int count, resin;

  /// Part of [resin] paid with Condensed Resin (40 each).
  final int condensed;
}

class DayPlan {
  DayPlan(this.date);
  final DateTime date;
  final runs = <PlannedRun>[];
  int get resin => runs.fold(0, (s, r) => s + r.resin);
}

class ResinSchedule {
  const ResinSchedule(this.days, this.finish, this.totalResin);
  final List<DayPlan> days;

  /// Day the last run is done; null when it takes longer than the horizon.
  final DateTime? finish;
  final int totalResin;
}

int _priority(FarmTask t, int weekday) => switch (t.kind) {
  TaskKind.weeklyBoss => 0,
  TaskKind.talentDomain ||
  TaskKind.weaponDomain => t.days.isEmpty || t.days.contains(weekday) ? 1 : 9,
  TaskKind.worldBoss => 2,
  TaskKind.expLeyLine => 3,
  TaskKind.moraLeyLine => 4,
};

/// Spends the daily resin by priority: the earlier phase first; inside a
/// phase, what is time-limited (weekly boss, domains open today) first.
ResinSchedule scheduleResin(
  List<FarmTask> tasks, {
  required DateTime start,
  int startResin = 180,
  int startCondensed = 0,
  int dailyResin = 180,
  int resinCap = 200,
  int maxDays = 365,
  Set<String> weeklyDoneThisWeek = const {},
}) {
  for (final t in tasks) {
    t.remaining = t.runs;
  }
  final days = <DayPlan>[];
  var resin = startResin;
  // Condensed Resin, in resin units: only domains and ley lines accept it.
  var condensed = startCondensed * 40;
  var total = 0;
  final weeklyDone = <String>{};
  var weeklyClaims = 0;
  DateTime? week;
  for (var i = 0; i < maxDays; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    if (week != monday) {
      week = monday;
      weeklyDone.clear();
      weeklyClaims = 0;
      // Bosses already claimed in the game this week (checked as done).
      if (i == 0) {
        weeklyDone.addAll(weeklyDoneThisWeek);
        weeklyClaims = weeklyDoneThisWeek.length;
      }
    }
    if (i > 0) {
      resin = (resin + dailyResin).clamp(
        0,
        resinCap > resin ? resinCap : resin,
      );
    }
    final day = DayPlan(date);
    final open =
        tasks
            .where((t) => t.remaining > 0 && _priority(t, date.weekday) < 9)
            .toList()
          ..sort((a, b) {
            final g = a.group.compareTo(b.group);
            return g != 0
                ? g
                : _priority(
                    a,
                    date.weekday,
                  ).compareTo(_priority(b, date.weekday));
          });
    for (final task in open) {
      var count = 0;
      var spent = 0;
      var fromCondensed = 0;
      final acceptsCondensed = switch (task.kind) {
        TaskKind.talentDomain ||
        TaskKind.weaponDomain ||
        TaskKind.expLeyLine ||
        TaskKind.moraLeyLine => true,
        _ => false,
      };
      while (task.remaining > 0) {
        final weekly = task.kind == TaskKind.weeklyBoss;
        final key = task.bossKey ?? task.title;
        if (weekly && weeklyDone.contains(key)) break;
        // Only the first three weekly boss claims of the week are discounted.
        final cost = weekly ? (weeklyClaims < 3 ? 30 : 60) : task.resin;
        if (acceptsCondensed && condensed >= cost) {
          condensed -= cost;
          fromCondensed += cost;
        } else if (resin >= cost) {
          resin -= cost;
        } else {
          break;
        }
        spent += cost;
        task.remaining--;
        count++;
        if (weekly) {
          weeklyDone.add(key);
          weeklyClaims++;
        }
      }
      if (count > 0) {
        day.runs.add(PlannedRun(task, count, spent, fromCondensed));
        total += spent;
      }
    }
    days.add(day);
    if (tasks.every((t) => t.remaining == 0)) {
      return ResinSchedule(days, date, total);
    }
  }
  return ResinSchedule(days, null, total);
}
