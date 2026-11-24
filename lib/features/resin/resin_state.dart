import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progression/data/scenario_repository.dart';

/// The player's resin, as in the game.
///
/// * Original Resin regenerates 1 every 8 minutes up to 200.
/// * Condensed Resin (max 5) is worth 40 and only works on domains and
///   ley lines, never on world or weekly bosses.
/// * Fragile and Transient Resin each restore 60 Original Resin.
class ResinState {
  const ResinState({
    required this.original,
    required this.updatedAt,
    this.condensed = 0,
    this.fragile = 0,
    this.transient = 0,
  });
  final int original, condensed, fragile, transient;

  /// When [original] was last set; regeneration counts from here.
  final DateTime updatedAt;

  static const cap = 200;
  static const maxCondensed = 5;
  static const condensedValue = 40;
  static const refillValue = 60;
  static const regen = Duration(minutes: 8);

  static ResinState initial(DateTime now) =>
      ResinState(original: cap, updatedAt: now);

  int _ticks(DateTime now) {
    final elapsed = now.difference(updatedAt);
    return elapsed.isNegative ? 0 : elapsed.inSeconds ~/ regen.inSeconds;
  }

  /// Original Resin right now, counting regeneration (never past the cap,
  /// but a value already above it from refills is kept).
  int originalAt(DateTime now) =>
      original >= cap ? original : (original + _ticks(now)).clamp(0, cap);

  /// Time until the next point, or null when full.
  Duration? nextIn(DateTime now) {
    if (originalAt(now) >= cap) return null;
    final passed = now.difference(updatedAt).inSeconds % regen.inSeconds;
    return Duration(seconds: regen.inSeconds - passed);
  }

  /// Time until Original Resin reaches 200, or null when full.
  Duration? fullIn(DateTime now) {
    final current = originalAt(now);
    if (current >= cap) return null;
    return nextIn(now)! + regen * (cap - current - 1);
  }

  /// Resin usable anywhere (original plus fragile and transient refills).
  int normalAt(DateTime now) =>
      originalAt(now) + refillValue * (fragile + transient);

  /// Everything together, condensed counted at 40.
  int totalAt(DateTime now) => normalAt(now) + condensedValue * condensed;

  /// Spends resin as the game does: [original] Original Resin and
  /// [condensed] Condensed Resin (negative values give them back).
  /// Regeneration keeps its progress towards the next point.
  ResinState spend(DateTime now, {int original = 0, int condensed = 0}) {
    final current = originalAt(now);
    final ticks = _ticks(now);
    final base = this.original >= cap || current >= cap
        ? now
        : updatedAt.add(regen * ticks);
    return copyWith(
      original: (current - original).clamp(0, 1 << 30),
      updatedAt: base,
      condensed: (this.condensed - condensed).clamp(0, maxCondensed),
    );
  }

  ResinState copyWith({
    int? original,
    DateTime? updatedAt,
    int? condensed,
    int? fragile,
    int? transient,
  }) => ResinState(
    original: original ?? this.original,
    updatedAt: updatedAt ?? this.updatedAt,
    condensed: condensed ?? this.condensed,
    fragile: fragile ?? this.fragile,
    transient: transient ?? this.transient,
  );

  Map<String, Object?> toJson() => {
    'original': original,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'condensed': condensed,
    'fragile': fragile,
    'transient': transient,
  };

  static ResinState? fromJson(Map<String, dynamic>? json) {
    final at = DateTime.tryParse('${json?['updatedAt']}');
    if (json == null || at == null || json['original'] is! int) return null;
    int count(String key) => json[key] is int ? json[key] as int : 0;
    return ResinState(
      original: json['original'] as int,
      updatedAt: at,
      condensed: count('condensed'),
      fragile: count('fragile'),
      transient: count('transient'),
    );
  }
}

/// Clock used for regeneration; tests replace it.
final resinClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final resinProvider = AsyncNotifierProvider<ResinController, ResinState>(
  ResinController.new,
);

class ResinController extends AsyncNotifier<ResinState> {
  static const _key = 'resina';

  @override
  Future<ResinState> build() async {
    final stored = await ref.watch(scenarioRepositoryProvider).load(_key);
    return ResinState.fromJson(stored) ??
        ResinState.initial(ref.read(resinClockProvider)());
  }

  /// Saves what the player typed; Original Resin regenerates from now.
  Future<void> set({
    required int original,
    required int condensed,
    required int fragile,
    required int transient,
  }) async {
    final next = ResinState(
      original: original,
      updatedAt: ref.read(resinClockProvider)(),
      condensed: condensed,
      fragile: fragile,
      transient: transient,
    );
    await ref.read(scenarioRepositoryProvider).save(_key, next.toJson());
    state = AsyncData(next);
  }

  /// Spends (or, with negative values, gives back) resin after a task.
  Future<ResinState> spend({int original = 0, int condensed = 0}) async {
    final now = ref.read(resinClockProvider)();
    final current = state.asData?.value ?? await future;
    final next = current.spend(now, original: original, condensed: condensed);
    await ref.read(scenarioRepositoryProvider).save(_key, next.toJson());
    state = AsyncData(next);
    return next;
  }
}
