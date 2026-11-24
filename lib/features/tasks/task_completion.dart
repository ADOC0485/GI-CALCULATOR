import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../builds/data/build_repository.dart';
import '../builds/domain/resin_planner.dart';
import '../builds/presentation/build_page.dart' show formatNumber, materialIcon;
import '../catalog/data/genshin_api_catalog.dart' show moraId;
import '../catalog/domain/catalog.dart';
import '../catalog/presentation/catalog_provider.dart';
import '../profiles/profile.dart';
import '../progression/domain/inventory_plan.dart';
import '../resin/resin_bar.dart';
import '../resin/resin_state.dart';
import '../resin/wallet.dart';
import 'task_log.dart';

/// Something on a checklist that can be checked as done.
class TaskRef {
  const TaskRef({
    required this.key,
    required this.label,
    this.original = 0,
    this.condensed = 0,
    this.acceptsCondensed = false,
    this.bossKey,
    this.materialIds = const [],
    this.primogems = 0,
    this.commission = false,
  });

  /// A resin run from the plan (domain, boss, ley line…).
  factory TaskRef.run(PlannedRun run) => TaskRef(
    key: runKey(run.task),
    label: '${run.task.title} × ${run.count}',
    original: run.resin - run.condensed,
    condensed: run.condensed ~/ ResinState.condensedValue,
    acceptsCondensed: switch (run.task.kind) {
      TaskKind.talentDomain ||
      TaskKind.weaponDomain ||
      TaskKind.expLeyLine ||
      TaskKind.moraLeyLine => true,
      _ => false,
    },
    bossKey: run.task.bossKey,
    materialIds: run.task.materialIds,
  );

  /// Something collected without resin (specialties, enemy drops…).
  factory TaskRef.free(FreeTask task) => TaskRef(
    key: 'libre|${task.materialId ?? task.title}',
    label: task.title,
    materialIds: task.materialIds,
  );

  static String runKey(FarmTask task) => 'resina|${task.owner}|${task.title}';

  final String key, label;

  /// Resin the plan expects this to cost.
  final int original, condensed;
  final bool acceptsCondensed;
  final String? bossKey;

  /// Items whose new totals are asked for after doing it.
  final List<String> materialIds;

  /// Primogems added when checked (commissions, Welkin Moon).
  final int primogems;

  /// Daily commissions: also adds the commission Mora.
  final bool commission;

  bool get usesResin => original > 0 || condensed > 0;
}

DateTime _today(WidgetRef ref) =>
    gameDay(DateTime.now(), ref.read(activeServerProvider));

void _refresh(WidgetRef ref) {
  ref.invalidate(inventoryProvider);
  ref.invalidate(doneTodayProvider);
  ref.invalidate(weeklyBossesDoneProvider);
  ref.invalidate(historyProvider);
}

/// Checks [task] as done: asks whether resin was spent now, then how many
/// of its materials the player owns now (that answer is final). Returns
/// false when the player cancels, so the box stays unchecked.
Future<bool> completeTask(
  BuildContext context,
  WidgetRef ref,
  TaskRef task,
) async {
  final repo = ref.read(buildRepositoryProvider);
  var original = 0, condensed = 0;
  if (task.usesResin) {
    final answer = await showDialog<({int original, int condensed})>(
      context: context,
      builder: (_) => _ResinQuestion(task: task),
    );
    if (answer == null) return false;
    original = answer.original;
    condensed = answer.condensed;
  }
  final inventory = await repo.inventory();
  final before = <String, int>{};
  if (task.materialIds.isNotEmpty && context.mounted) {
    final counts = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => CountsQuestion(
        title: task.label,
        ids: task.materialIds,
        owned: inventory.owned,
      ),
    );
    if (counts != null && counts.isNotEmpty) {
      for (final id in counts.keys) {
        before[id] = inventory.owned(id);
      }
      await repo.setOwned(counts);
    }
  }
  var mora = 0;
  if (task.commission) {
    final wallet = await ref.read(walletProvider.future);
    mora = wallet.commissionMora;
    final now = before.containsKey(moraId)
        ? (await repo.inventory()).mora
        : inventory.mora;
    await repo.setOwned({moraId: now + mora});
  }
  if (task.primogems > 0) {
    await ref.read(walletProvider.notifier).addPrimogems(task.primogems);
  }
  if (original > 0 || condensed > 0) {
    await ref
        .read(resinProvider.notifier)
        .spend(original: original, condensed: condensed);
  }
  await ref
      .read(taskLogRepositoryProvider)
      .add(
        _today(ref),
        DoneTask(
          key: task.key,
          label: task.label,
          at: DateTime.now(),
          original: original,
          condensed: condensed,
          mora: mora,
          primogems: task.primogems,
          bossKey: task.bossKey,
          before: before,
        ),
      );
  await repo.log(
    'Hecho: ${task.label}'
    '${original + condensed * ResinState.condensedValue > 0 ? ' (−${original + condensed * ResinState.condensedValue} de resina)' : ''}.',
  );
  _refresh(ref);
  if ((mora > 0 || task.primogems > 0) && context.mounted) {
    final added = [
      if (task.primogems > 0) '${task.primogems} Protogemas',
      if (mora > 0) '${formatNumber(mora)} de Mora (aprox.)',
    ].join(' y ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          'Se sumaron $added. Recuerda que puedes ajustar tus Protogemas '
          '(barra de arriba) y tu Mora (Inventario) para que queden igual que en el juego.',
        ),
        action: SnackBarAction(
          label: 'Ajustar',
          onPressed: () {
            if (context.mounted) {
              showDialog<void>(
                context: context,
                builder: (_) => const ResinDialog(),
              );
            }
          },
        ),
      ),
    );
  }
  return true;
}

/// Unchecks [done]; offers to give back what checking it changed.
/// Returns false when the player cancels.
Future<bool> undoTask(
  BuildContext context,
  WidgetRef ref,
  DoneTask done,
) async {
  var revert = false;
  if (done.changedSomething) {
    final spent = done.original + done.condensed * ResinState.condensedValue;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Desmarcar «${done.label}»?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Al marcarla se cambió:'),
            const SizedBox(height: 8),
            if (spent > 0)
              Text(
                '• Se descontaron ${done.original} de resina original'
                '${done.condensed > 0 ? ' y ${done.condensed} concentrada' : ''}.',
              ),
            if (done.primogems > 0)
              Text('• Se sumaron ${done.primogems} Protogemas.'),
            if (done.mora > 0)
              Text('• Se sumaron ${formatNumber(done.mora)} de Mora.'),
            if (done.before.isNotEmpty)
              const Text('• Se actualizó tu inventario.'),
            const SizedBox(height: 8),
            const Text('¿Lo dejo todo como estaba antes?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('undo-only'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo desmarcar'),
          ),
          FilledButton(
            key: const ValueKey('undo-revert'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desmarcar y deshacer'),
          ),
        ],
      ),
    );
    if (choice == null) return false;
    revert = choice;
  }
  final repo = ref.read(buildRepositoryProvider);
  if (revert) {
    if (done.original > 0 || done.condensed > 0) {
      await ref
          .read(resinProvider.notifier)
          .spend(original: -done.original, condensed: -done.condensed);
    }
    if (done.primogems > 0) {
      await ref.read(walletProvider.notifier).addPrimogems(-done.primogems);
    }
    final restore = Map.of(done.before);
    if (done.mora > 0) {
      final mora = restore[moraId] ?? (await repo.inventory()).mora - done.mora;
      restore[moraId] = mora < 0 ? 0 : mora;
    }
    if (restore.isNotEmpty) await repo.setOwned(restore);
  }
  await ref.read(taskLogRepositoryProvider).remove(_today(ref), done.key);
  await repo.log('Desmarcado: ${done.label}${revert ? ' (deshecho)' : ''}.');
  _refresh(ref);
  return true;
}

/// Checks or unchecks [task] depending on whether it is in [doneToday].
Future<void> toggleTask(
  BuildContext context,
  WidgetRef ref,
  TaskRef task,
  List<DoneTask> doneToday,
) async {
  final done = doneToday.where((t) => t.key == task.key).firstOrNull;
  if (done == null) {
    await completeTask(context, ref, task);
  } else {
    await undoTask(context, ref, done);
  }
}

Widget _numberField(
  TextEditingController c,
  String label, {
  Key? key,
  double width = 120,
}) => SizedBox(
  width: width,
  child: TextField(
    key: key,
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  ),
);

/// "When did you do it?": spend the resin now, or it was already counted.
class _ResinQuestion extends ConsumerStatefulWidget {
  const _ResinQuestion({required this.task});
  final TaskRef task;
  @override
  ConsumerState<_ResinQuestion> createState() => _ResinQuestionState();
}

class _ResinQuestionState extends ConsumerState<_ResinQuestion> {
  late final original = TextEditingController(text: '${widget.task.original}');
  late final condensed = TextEditingController(
    text: '${widget.task.condensed}',
  );

  @override
  void dispose() {
    original.dispose();
    condensed.dispose();
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final resin = ref.watch(resinProvider).asData?.value;
    final now = ref.read(resinClockProvider)();
    final showCondensed =
        widget.task.acceptsCondensed &&
        (widget.task.condensed > 0 || (resin?.condensed ?? 0) > 0);
    return AlertDialog(
      title: Text(widget.task.label),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Lo hiciste ahora o ya lo habías hecho antes?'),
              const SizedBox(height: 8),
              Text(
                'Si lo hiciste ahora, se descuenta esta resina para que quede igual que en el juego. '
                'Si ya lo habías hecho (y tu resina ya está bien), solo se marca.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _numberField(
                    original,
                    'Resina original',
                    key: const ValueKey('done-original'),
                  ),
                  if (showCondensed)
                    _numberField(
                      condensed,
                      'Concentrada',
                      key: const ValueKey('done-condensed'),
                    ),
                ],
              ),
              if (resin != null) ...[
                const SizedBox(height: 12),
                Text(
                  'En la app tienes ${resin.originalAt(now)} de resina original'
                  '${resin.condensed > 0 ? ' y ${resin.condensed} concentrada' : ''}.',
                ),
              ],
              if (widget.task.bossKey != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Este jefe semanal queda hecho hasta el lunes. Los 3 primeros de la semana cuestan 30.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const ValueKey('done-before'),
          onPressed: () => Navigator.pop(context, (original: 0, condensed: 0)),
          child: const Text('Ya lo había hecho'),
        ),
        FilledButton(
          key: const ValueKey('done-now'),
          onPressed: () => Navigator.pop(context, (
            original: _read(original),
            condensed: showCondensed ? _read(condensed) : 0,
          )),
          child: const Text('Lo hice ahora'),
        ),
      ],
    );
  }
}

/// "How many do you have now?": the player's answer replaces the inventory.
class CountsQuestion extends ConsumerStatefulWidget {
  const CountsQuestion({
    super.key,
    required this.title,
    required this.ids,
    required this.owned,
  });
  final String title;
  final List<String> ids;
  final int Function(String id) owned;
  @override
  ConsumerState<CountsQuestion> createState() => _CountsQuestionState();
}

class _CountsQuestionState extends ConsumerState<CountsQuestion> {
  late final fields = {
    for (final id in widget.ids)
      id: TextEditingController(text: '${widget.owned(id)}'),
  };

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _name(Map<String, CatalogRecord> byId, String id) {
    for (final e in [...characterExpItems, ...weaponExpItems]) {
      if (e.id == id) return e.label;
    }
    return byId[id]?.name ?? (id == moraId ? 'Mora' : id);
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(catalogProvider).asData?.value;
    final byId = {
      for (final r in bundle?.records ?? const <CatalogRecord>[]) r.id: r,
    };
    return AlertDialog(
      title: const Text('¿Cuánto tienes ahora?'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                'Escribe el total que ves en el juego. Eso queda en tu inventario '
                'y el plan se recalcula.',
              ),
              const SizedBox(height: 16),
              for (final id in widget.ids)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      materialIcon(byId[id]?.image),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_name(byId, id))),
                      const SizedBox(width: 10),
                      _numberField(
                        fields[id]!,
                        'Tienes',
                        key: ValueKey('count-$id'),
                        width: id == moraId ? 140 : 96,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('counts-skip'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Omitir'),
        ),
        FilledButton(
          key: const ValueKey('counts-save'),
          onPressed: () => Navigator.pop(context, {
            for (final e in fields.entries)
              e.key: int.tryParse(e.value.text.trim()) ?? 0,
          }),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Tasks checked today that the plan no longer lists (it recalculates after
/// resin and inventory change), so they can still be unchecked.
class DoneTodayTiles extends ConsumerWidget {
  const DoneTodayTiles({super.key, required this.shown, this.where});

  /// Keys already drawn as checked boxes elsewhere in the list.
  final Set<String> shown;

  /// Which done tasks belong to this list (all when null).
  final bool Function(DoneTask task)? where;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(doneTodayProvider).asData?.value ?? const [];
    final extra = done
        .where((t) => !shown.contains(t.key) && (where?.call(t) ?? true))
        .toList();
    if (extra.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Hecho hoy',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final t in extra)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: true,
            onChanged: (_) => undoTask(context, ref, t),
            secondary: const Icon(Icons.check_circle_outline),
            title: Text(t.label),
            subtitle: t.original + t.condensed > 0
                ? Text(
                    '−${t.original + t.condensed * ResinState.condensedValue} de resina',
                  )
                : null,
          ),
      ],
    );
  }
}
