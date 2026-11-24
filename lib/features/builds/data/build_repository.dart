import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/data/genshin_api_catalog.dart' show moraId;
import '../../progression/data/scenario_repository.dart';
import '../../progression/domain/inventory_plan.dart';
import '../domain/build.dart';

final buildRepositoryProvider = Provider(
  (ref) => BuildRepository(ref.watch(scenarioRepositoryProvider)),
);

final buildsProvider = FutureProvider<List<GenshinBuild>>(
  (ref) => ref.watch(buildRepositoryProvider).loadAll(),
);

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

  Future<List<GenshinBuild>> loadAll() async {
    final stored = await scenarios.load(_builds);
    final items = stored?['items'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) GenshinBuild.fromJson(item),
    ];
  }

  Future<void> save(GenshinBuild build) async {
    final all = await loadAll();
    final index = all.indexWhere((b) => b.id == build.id);
    if (index < 0) {
      all.add(build);
    } else {
      all[index] = build;
    }
    await scenarios.save(_builds, {
      'schema': 1,
      'items': [for (final b in all) b.toJson()],
    });
  }

  Future<void> delete(String id) async {
    final all = await loadAll()
      ..removeWhere((b) => b.id == id);
    await scenarios.save(_builds, {
      'schema': 1,
      'items': [for (final b in all) b.toJson()],
    });
  }

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
