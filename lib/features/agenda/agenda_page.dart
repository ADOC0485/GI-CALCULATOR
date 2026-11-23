import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/presentation/page_frame.dart';
import '../builds/data/build_repository.dart';
import '../builds/domain/build.dart';
import '../builds/domain/resin_planner.dart';
import '../builds/presentation/build_page.dart';
import '../catalog/domain/catalog.dart';
import '../resin/resin_bar.dart';
import '../resin/resin_state.dart';
import '../catalog/presentation/catalog_provider.dart';
import '../progression/domain/inventory_plan.dart';
import '../progression/domain/progression_calculator.dart';
import '../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;

/// Every build planned together: one resin budget, builds in list order.
class AgendaPlan {
  const AgendaPlan(this.schedule, this.free, this.finishByBuild);
  final ResinSchedule schedule;
  final Map<String, List<FreeTask>> free;
  final Map<String, DateTime?> finishByBuild;
}

AgendaPlan planAgenda({
  required CatalogBundle bundle,
  required ProgressionRules rules,
  required List<GenshinBuild> builds,
  required Inventory inventory,
  required DateTime start,
  int startResin = 180,
  int startCondensed = 0,
}) {
  final byId = {for (final r in bundle.records) r.id: r};
  final pool = InventoryPool(inventory);
  final rates = LeyLineRates.forWorldLevel(inventory.worldLevel);
  final tasks = <FarmTask>[];
  final free = <String, List<FreeTask>>{};
  final names = <String>[];
  for (final (i, build) in builds.indexed) {
    final name = byId[build.characterId]?.name ?? build.characterId;
    names.add(name);
    final phases = buildNeedsFromPool(
      bundle: bundle,
      rules: rules,
      build: build,
      pool: pool,
    );
    final farm = farmTasks(
      bundle: bundle,
      phases: phases,
      rates: rates,
      groupBase: i * BuildPhase.values.length,
      owner: name,
    );
    tasks.addAll(farm.tasks);
    if (farm.free.isNotEmpty) free[name] = farm.free;
  }
  final schedule = scheduleResin(
    tasks,
    start: start,
    startResin: startResin,
    startCondensed: startCondensed,
  );
  final finish = <String, DateTime?>{};
  for (final name in names) {
    final own = tasks.where((t) => t.owner == name);
    if (own.isEmpty) {
      finish[name] = start;
    } else if (own.any((t) => t.remaining > 0)) {
      finish[name] = null;
    } else {
      finish[name] = schedule.days
          .lastWhere((d) => d.runs.any((r) => r.task.owner == name))
          .date;
    }
  }
  return AgendaPlan(schedule, free, finish);
}

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});
  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  final today = DateTime.now();
  final done = <String, Set<String>>{};

  String _key(DateTime d) => 'agenda-${dayKey(d)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(buildRepositoryProvider);
    for (var i = 0; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final set = await repo.checked(_key(d), d);
      if (!mounted) return;
      setState(() => done[dayKey(d)] = set);
    }
  }

  Future<void> _toggle(DateTime d, String key, bool on) async {
    final set = done.putIfAbsent(dayKey(d), () => {});
    setState(() => on ? set.add(key) : set.remove(key));
    await ref.read(buildRepositoryProvider).setChecked(_key(d), d, set);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundle = ref.watch(catalogProvider).asData?.value;
    final rules = ref.watch(progressionRulesProvider).asData?.value;
    final builds = ref.watch(buildsProvider).asData?.value;
    final inventory = ref.watch(inventoryProvider).asData?.value;
    final resin = ref.watch(resinProvider).asData?.value;
    if (bundle == null || rules == null || builds == null || inventory == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final byId = {for (final r in bundle.records) r.id: r};
    AgendaPlan? plan;
    String? error;
    try {
      plan = builds.isEmpty
          ? null
          : planAgenda(
              bundle: bundle,
              rules: rules,
              builds: builds,
              inventory: inventory,
              start: today,
              startResin: resin?.normalAt(today) ?? 180,
              startCondensed: resin?.condensed ?? 0,
            );
    } on CalculationException catch (e) {
      error = e.message;
    }
    String date(DateTime d) =>
        '${weekdayNames[d.weekday - 1]} ${d.day}/${d.month}';

    return PageFrame(
      title: 'Agenda',
      subtitle: 'Tu semana de farmeo con todas tus builds y la misma resina.',
      children: [
        if (builds.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aún no tienes builds. Añade una en Inicio y aquí verás qué farmear cada día.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Ir a Inicio'),
                  ),
                ],
              ),
            ),
          ),
        if (error != null)
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        if (plan != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                  resin == null
                      ? 'Resina: cargando…'
                      : 'Resina para hoy: ${resin.normalAt(today)}'
                            '${resin.condensed > 0 ? ' + ${resin.condensed} concentrada' : ''}',
                ),
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ResinDialog(),
                  ),
                  icon: const Icon(Icons.nightlight_round, size: 18),
                  label: const Text('Editar resina'),
                ),
                      Text('Nivel de mundo ${inventory.worldLevel}'),
                      TextButton(
                        onPressed: () => context.go('/settings'),
                        child: const Text('Cambiar en Ajustes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Orden: tus builds como aparecen en Inicio; en cada una, primero el nivel, '
                    'luego el arma y al final los talentos. Los dominios salen en sus días y '
                    'cada jefe semanal una vez por semana (los 3 primeros a 30 de resina).',
                  ),
                  const SizedBox(height: 12),
                  for (final e in plan.finishByBuild.entries)
                    Text(
                      e.value == null
                          ? '• ${e.key}: más de un año a este ritmo'
                          : '• ${e.key}: listo el ${date(e.value!)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final day in plan.schedule.days.take(7))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              day.date.day == today.day && day.date.month == today.month
                                  ? 'Hoy · ${date(day.date)}'
                                  : date(day.date),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text('${day.resin} de resina'),
                        ],
                      ),
                      if (day.runs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Nada con resina: aprovecha para explorar o la Tetera.'),
                        ),
                      for (final run in day.runs)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: done[dayKey(day.date)]?.contains(
                                '${run.task.owner}:${run.task.title}',
                              ) ??
                              false,
                          onChanged: (v) => _toggle(
                            day.date,
                            '${run.task.owner}:${run.task.title}',
                            v!,
                          ),
                          secondary: materialIcon(byId[run.task.materialId]?.image),
                          title: Text('${run.task.title} × ${run.count}'),
                          subtitle: Text(
                            '${run.task.owner} · ${run.task.phase.label} · ${run.resin} de resina'
                            '${run.condensed > 0 ? ' (${run.condensed ~/ 40} concentrada)' : ''}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (plan.free.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin gastar resina', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final e in plan.free.entries) ...[
                      Text(e.key, style: theme.textTheme.titleSmall),
                      for (final task in e.value)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: materialIcon(byId[task.materialId]?.image),
                          title: Text(task.title),
                          trailing: Text('Faltan ${formatNumber(task.missing)}'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
