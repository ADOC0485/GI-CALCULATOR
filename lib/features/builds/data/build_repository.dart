import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/genshin_api_catalog.dart' show moraId;
import '../../progression/data/scenario_repository.dart';
import '../../progression/domain/inventory_plan.dart';
import '../domain/build.dart';

final buildRepositoryProvider = Provider(
  (ref) => BuildRepository(ref.watch(scenarioRepositoryProvider)),
);

/// Builds in progress, in priority order (the first one gets materials first).
final buildsProvider = FutureProvider<List<GenshinBuild>>(
  (ref) async => [
    for (final b in await ref.watch(buildRepositoryProvider).loadAll())
      if (!b.finished) b,
  ],
);

/// Builds that reached their goal, newest first.
final finishedBuildsProvider = FutureProvider<List<GenshinBuild>>((ref) async {
  final all = await ref.watch(buildRepositoryProvider).loadAll();
  return [
    for (final b in all)
      if (b.finished) b,
  ]..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
});

/// How many builds can be in progress at once.
final buildLimitProvider = FutureProvider<int>(
  (ref) => ref.watch(buildRepositoryProvider).activeLimit(),
);

/// Raised when a new build would go over the limit of builds in progress.
class BuildLimitException implements Exception {
  const BuildLimitException(this.limit);
  final int limit;
  String get message =>
      'Ya tienes $limit builds en proceso, el máximo. Termina o borra una, '
      'o cambia el límite en Ajustes.';
  @override
  String toString() => message;
}

final inventoryProvider = FutureProvider<Inventory>(
  (ref) => ref.watch(buildRepositoryProvider).inventory(),
);

final historyProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(buildRepositoryProvider).history(),
);

class HistoryEntry {
  const HistoryEntry(this.at, this.text);
  final DateTime at;
  final String text;
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Builds, the shared inventory and daily checklists, stored with the
/// calculator scenarios on this device.
class BuildRepository {
  BuildRepository(this.scenarios);
  final ScenarioRepository scenarios;
  static const _builds = 'builds';
  static const inventoryKey = 'inventario';

  /// Recommended number of builds in progress at the same time.
  static const defaultLimit = 4;

  Future<Map<String, dynamic>?> _doc() => scenarios.load(_builds);

  /// Every build, finished ones included, in priority order.
  Future<List<GenshinBuild>> loadAll() async {
    final items = (await _doc())?['items'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) GenshinBuild.fromJson(item),
    ];
  }

  Future<int> activeLimit() async {
    final limit = (await _doc())?['limit'];
    return limit is int && limit > 0 ? limit : defaultLimit;
  }

  Future<void> _write(List<GenshinBuild> all, {int? limit}) async =>
      scenarios.save(_builds, {
        'schema': 2,
        'limit': limit ?? await activeLimit(),
        'items': [for (final b in all) b.toJson()],
      });

  Future<void> setActiveLimit(int limit) async =>
      _write(await loadAll(), limit: limit.clamp(1, 99));

  /// Adds or replaces a build. New builds go last (lowest priority) and
  /// throw [BuildLimitException] when the limit of builds in progress is full.
  Future<void> save(GenshinBuild build) async {
    final all = await loadAll();
    final index = all.indexWhere((b) => b.id == build.id);
    if (index < 0) {
      final limit = await activeLimit();
      if (!build.finished && all.where((b) => !b.finished).length >= limit) {
        throw BuildLimitException(limit);
      }
      all.add(build);
    } else {
      all[index] = build;
    }
    await _write(all);
  }

  /// Moves a build in progress one place up (more priority) or down.
  Future<void> move(String id, {required bool up}) async {
    final all = await loadAll();
    final active = [
      for (final (i, b) in all.indexed)
        if (!b.finished) i,
    ];
    final at = active.indexWhere((i) => all[i].id == id);
    final other = up ? at - 1 : at + 1;
    if (at < 0 || other < 0 || other >= active.length) return;
    final a = active[at], b = active[other];
    final moved = all[a];
    all[a] = all[b];
    all[b] = moved;
    await _write(all);
  }

  Future<void> delete(String id) async => _write(
    await loadAll()
      ..removeWhere((b) => b.id == id),
  );

  Future<Map<String, dynamic>> rawInventory() async =>
      await scenarios.load(inventoryKey) ?? {'schema': 1};

  Future<Inventory> inventory() async =>
      Inventory.fromJson(await rawInventory());

  /// Merges [changes] into the saved inventory (same format as the
  /// calculator: numbers stored as text).
  Future<void> updateInventory(Map<String, Object?> changes) async {
    final current = await rawInventory();
    final materials = {
      ...?(current['materials'] as Map?)?.cast<String, Object?>(),
      ...?(changes['materials'] as Map?)?.cast<String, Object?>(),
    };
    await scenarios.save(inventoryKey, {
      ...current,
      ...changes,
      'materials': materials,
    });
  }

  /// Sets how many of each item the player owns now (what they typed is
  /// final). EXP books, ores and Mora go to their own fields.
  Future<void> setOwned(Map<String, int> counts) async {
    final current = await rawInventory();
    List<Object?> list(String key) {
      final v = current[key];
      return [
        for (var i = 0; i < 3; i++) v is List && i < v.length ? v[i] : '',
      ];
    }

    final books = list('booksCharacter'), ores = list('booksWeapon');
    final materials = <String, Object?>{};
    Object? mora;
    counts.forEach((id, value) {
      final text = '$value';
      final b = characterExpItems.indexWhere((e) => e.id == id);
      final o = weaponExpItems.indexWhere((e) => e.id == id);
      if (b >= 0) {
        books[b] = text;
      } else if (o >= 0) {
        ores[o] = text;
      } else if (id == moraId) {
        mora = text;
      } else {
        materials[id] = text;
      }
    });
    await updateInventory({
      'booksCharacter': books,
      'booksWeapon': ores,
      'mora': ?mora,
      'materials': materials,
    });
  }

  static const _history = 'historial';

  Future<List<HistoryEntry>> history() async {
    final items = (await scenarios.load(_history))?['items'];
    if (items is! List) return [];
    return [
      for (final item in items.whereType<Map<String, dynamic>>())
        if (DateTime.tryParse('${item['at']}') != null &&
            item['text'] is String)
          HistoryEntry(DateTime.parse('${item['at']}'), item['text'] as String),
    ];
  }

  /// Appends a line to the progress log (keeps the latest 300).
  Future<void> log(String text) async {
    final all = [...await history(), HistoryEntry(DateTime.now(), text)];
    final kept = all.length > 300 ? all.sublist(all.length - 300) : all;
    await scenarios.save(_history, {
      'items': [
        for (final e in kept) {'at': e.at.toIso8601String(), 'text': e.text},
      ],
    });
  }

  Future<Set<String>> checked(String buildId, DateTime day) async {
    final stored = await scenarios.load('checklist:$buildId');
    if (stored?['day'] != dayKey(day)) return {};
    return {...?(stored?['done'] as List?)?.whereType<String>()};
  }

  Future<void> setChecked(String buildId, DateTime day, Set<String> done) =>
      scenarios.save('checklist:$buildId', {
        'day': dayKey(day),
        'done': done.toList(),
      });
}
