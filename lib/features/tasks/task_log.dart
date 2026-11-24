import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../builds/data/build_repository.dart' show dayKey;
import '../profiles/profile.dart';
import '../progression/data/scenario_repository.dart';

/// A task checked as done, with what checking it changed so it can be
/// undone: resin spent, Mora and Primogems added, inventory before.
class DoneTask {
  const DoneTask({
    required this.key,
    required this.label,
    required this.at,
    this.original = 0,
    this.condensed = 0,
    this.mora = 0,
    this.primogems = 0,
    this.bossKey,
    this.before = const {},
  });
  final String key, label;
  final DateTime at;

  /// Original and Condensed Resin taken from the counter.
  final int original, condensed;

  /// Mora and Primogems added (daily commissions, Welkin Moon).
  final int mora, primogems;

  /// Weekly boss claimed (whether or not resin was taken).
  final String? bossKey;

  /// Inventory counts before the player typed the new ones.
  final Map<String, int> before;

  bool get changedSomething =>
      original != 0 ||
      condensed != 0 ||
      mora != 0 ||
      primogems != 0 ||
      before.isNotEmpty;

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'at': at.toIso8601String(),
    'original': original,
    'condensed': condensed,
    'mora': mora,
    'primogems': primogems,
    'bossKey': bossKey,
    'before': before,
  };

  static DoneTask? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    if (json['key'] is! String || at == null) return null;
    int count(String k) => json[k] is int ? json[k] as int : 0;
    final before = json['before'];
    return DoneTask(
      key: json['key'] as String,
      label: json['label'] is String
          ? json['label'] as String
          : json['key'] as String,
      at: at,
      original: count('original'),
      condensed: count('condensed'),
      mora: count('mora'),
      primogems: count('primogems'),
      bossKey: json['bossKey'] as String?,
      before: before is Map
          ? {
              for (final e in before.entries)
                if (e.value is int) '${e.key}': e.value as int,
            }
          : const {},
    );
  }
}

/// Tasks done per game day, kept with the profile's data.
class TaskLogRepository {
  TaskLogRepository(this.scenarios);
  final ScenarioRepository scenarios;

  String _key(DateTime day) => 'hechas:${dayKey(day)}';

  Future<List<DoneTask>> day(DateTime day) async {
    final items = (await scenarios.load(_key(day)))?['items'];
    if (items is! List) return [];
    return [for (final i in items) ?DoneTask.fromJson(i)];
  }

  Future<void> _save(DateTime day, List<DoneTask> items) =>
      scenarios.save(_key(day), {
        'items': [for (final t in items) t.toJson()],
      });

  Future<void> add(DateTime day, DoneTask task) async {
    final items = [
      ...(await this.day(day)).where((t) => t.key != task.key),
      task,
    ];
    await _save(day, items);
  }

  Future<void> remove(DateTime day, String key) async =>
      _save(day, [...(await this.day(day)).where((t) => t.key != key)]);

  /// Weekly bosses claimed from Monday (the weekly reset) up to [today].
  Future<Set<String>> weeklyBosses(DateTime today) async {
    final bosses = <String>{};
    for (var d = 0; d < today.weekday; d++) {
      final date = DateTime(today.year, today.month, today.day - d);
      for (final t in await day(date)) {
        if (t.bossKey != null) bosses.add(t.bossKey!);
      }
    }
    return bosses;
  }
}

final taskLogRepositoryProvider = Provider(
  (ref) => TaskLogRepository(ref.watch(scenarioRepositoryProvider)),
);

/// Today's game day on the profile's server (it changes at 04:00 there).
DateTime todayFor(Ref ref) =>
    gameDay(DateTime.now(), ref.watch(activeServerProvider));

/// What was checked as done today.
final doneTodayProvider = FutureProvider<List<DoneTask>>(
  (ref) => ref.watch(taskLogRepositoryProvider).day(todayFor(ref)),
);

/// Weekly bosses already claimed this week.
final weeklyBossesDoneProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(taskLogRepositoryProvider).weeklyBosses(todayFor(ref)),
);
