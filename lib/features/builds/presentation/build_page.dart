import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/page_frame.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../progression/domain/inventory_plan.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;
import '../../resin/resin_bar.dart';
import '../../resin/resin_state.dart';
import '../data/build_repository.dart';
import '../domain/build.dart';
import '../domain/resin_planner.dart';
import 'build_editor_dialog.dart';

const weekdayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String formatNumber(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]} ',
);

Widget materialIcon(String? url, {double size = 32}) => SizedBox(
  width: size,
  height: size,
  child: url == null
      ? Icon(Icons.inventory_2_outlined, size: size * 0.7)
      : Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(Icons.inventory_2_outlined, size: size * 0.7),
        ),
);

/// Detail of one build: progress, resin plan, checklist and inventory.
class BuildPage extends ConsumerStatefulWidget {
  const BuildPage({required this.buildId, super.key});
  final String buildId;
  @override
  ConsumerState<BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends ConsumerState<BuildPage> {
  final owned = <String, TextEditingController>{};
  final books = List.generate(3, (_) => TextEditingController());
  final ores = List.generate(3, (_) => TextEditingController());
  final mora = TextEditingController();
  final worldLevel = TextEditingController();
  Set<String> done = {};
  bool inventoryLoaded = false;
  String? notice;
  final today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final repo = ref.read(buildRepositoryProvider);
    final inventory = await repo.inventory();
    final checked = await repo.checked(widget.buildId, today);
    if (!mounted) return;
    setState(() {
      done = checked;
      inventory.materials.forEach((id, v) => _owned(id).text = '$v');
      for (var i = 0; i < 3; i++) {
        books[i].text = _text(inventory.characterBooks[i]);
        ores[i].text = _text(inventory.weaponOres[i]);
      }
      mora.text = _text(inventory.mora);
      worldLevel.text = '${inventory.worldLevel}';
      inventoryLoaded = true;
    });
  }

  static String _text(int v) => v == 0 ? '' : '$v';

  TextEditingController _owned(String id) =>
      owned.putIfAbsent(id, TextEditingController.new);

  int _count(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [mora, worldLevel, ...books, ...ores, ...owned.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Inventory _inventory() => Inventory(
    materials: {
      for (final e in owned.entries)
        if (_count(e.value) > 0) e.key: _count(e.value),
    },
    characterBooks: [for (final b in books) _count(b)],
    weaponOres: [for (final o in ores) _count(o)],
    mora: _count(mora),
    worldLevel: int.tryParse(worldLevel.text.trim()) ?? 8,
  );

  Future<void> _saveInventory() async {
    try {
      await ref.read(buildRepositoryProvider).updateInventory({
        'materials': {
          for (final e in owned.entries) e.key: e.value.text.trim(),
        },
        'booksCharacter': [for (final b in books) b.text.trim()],
        'booksWeapon': [for (final o in ores) o.text.trim()],
        'mora': mora.text.trim(),
      });
      await ref.read(buildRepositoryProvider).log('Inventario actualizado.');
      ref.invalidate(inventoryProvider);
      ref.invalidate(historyProvider);
      setState(() => notice = 'Inventario guardado. Sirve para todas tus builds.');
    } catch (_) {
      setState(() => notice = 'No se pudo guardar el inventario.');
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => value ? done.add(key) : done.remove(key));
    await ref.read(buildRepositoryProvider).setChecked(widget.buildId, today, done);
  }

  Widget _card(String title, List<Widget> children, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );

  Widget _numberField(TextEditingController c, String label, {double width = 110}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            hintText: '0',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => notice = null),
        ),
      );

  String _stateLabel(ProgressionState s) =>
      '${s.level}/${ProgressionRules.caps[s.ascension.clamp(0, 6)]}';

  @override
  Widget build(BuildContext context) {
    final bundleValue = ref.watch(catalogProvider);
    final rulesValue = ref.watch(progressionRulesProvider);
    final buildsValue = ref.watch(buildsProvider);
    final bundle = bundleValue.asData?.value;
    final rules = rulesValue.asData?.value;
    final builds = buildsValue.asData?.value;
    if (bundle == null || rules == null || builds == null || !inventoryLoaded) {
      if (bundleValue.hasError || rulesValue.hasError || buildsValue.hasError) {
        return const Center(child: Text('No se pudo abrir la build.'));
      }
      return const Center(child: CircularProgressIndicator());
    }
    final build = builds.where((b) => b.id == widget.buildId).firstOrNull;
    if (build == null) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Esta build ya no existe · Volver al inicio'),
        ),
      );
    }
    final byId = {for (final r in bundle.records) r.id: r};
    final character = byId[build.characterId];
    final weapon = build.weaponId == null ? null : byId[build.weaponId];
    final theme = Theme.of(context);
    final inventory = _inventory();
    final resin = ref.watch(resinProvider).asData?.value;

    List<PhaseNeeds>? phases;
    FarmPlan? farm;
    ResinSchedule? schedule;
    String? error;
    try {
      phases = buildNeeds(bundle: bundle, rules: rules, build: build, inventory: inventory);
      farm = farmTasks(
        bundle: bundle,
        phases: phases,
        rates: LeyLineRates.forWorldLevel(inventory.worldLevel),
      );
      schedule = scheduleResin(
        farm.tasks,
        start: today,
        startResin: resin?.normalAt(today) ?? 180,
        startCondensed: resin?.condensed ?? 0,
      );
    } on CalculationException catch (e) {
      error = e.message;
    }

    final good = TextStyle(color: theme.colorScheme.primary);
    final bad = TextStyle(color: theme.colorScheme.error);

    return PageFrame(
      title: '${character?.name ?? 'Personaje'}${weapon == null ? '' : ' + ${weapon.name}'}',
      subtitle: 'Tu guía de mejora: qué te falta y en qué gastar la resina cada día.',
      action: Wrap(
        spacing: 8,
        children: [
          IconButton.filledTonal(
            tooltip: 'Volver al inicio',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton.filledTonal(
            tooltip: 'Eliminar build',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Eliminar esta build?'),
                  content: const Text('Tu inventario se conserva.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await ref.read(buildRepositoryProvider).delete(build.id);
              await ref
                  .read(buildRepositoryProvider)
                  .log('Build eliminada: ${character?.name ?? build.characterId}.');
              ref.invalidate(buildsProvider);
              ref.invalidate(historyProvider);
              if (context.mounted) context.go('/dashboard');
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      children: [
        _card(
          'Tu avance',
          [
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    materialIcon(character?.image, size: 48),
                    const SizedBox(width: 12),
                    Text(
                      '${character?.name}\nNivel ${_stateLabel(build.characterNow)} → ${_stateLabel(build.characterGoal)}'
                      '${build.talentsOn ? '\nTalentos ${build.characterNow.talents.join('/')} → ${build.characterGoal.talents.join('/')}' : ''}',
                    ),
                  ],
                ),
                if (weapon != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      materialIcon(weapon.image, size: 48),
                      const SizedBox(width: 12),
                      Text(
                        '${weapon.name}\nNivel ${_stateLabel(build.weaponNow)} → ${_stateLabel(build.weaponGoal)}',
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (error != null) Text(error, style: bad),
            for (final p in phases ?? <PhaseNeeds>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      p.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: p.done ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.done
                            ? '${p.phase.label}: ¡tienes todo!'
                            : '${p.phase.label}: faltan '
                                  '${p.plan.lines.where((l) => l.missing > 0).length} materiales'
                                  '${p.plan.expMissing > 0 ? ', ${formatNumber(p.plan.expMissing)} de EXP' : ''}'
                                  '${p.plan.moraMissing > 0 ? ', ${formatNumber(p.plan.moraMissing)} de Mora' : ''}',
                      ),
                    ),
                  ],
                ),
              ),
          ],
          trailing: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BuildEditorDialog(bundle: bundle, existing: build),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Actualizar progreso'),
          ),
        ),
        if (schedule != null && farm != null) ...[
          _card('Plan de resina', [
            Wrap(
              spacing: 12,
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
            Text(
              farm.tasks.isEmpty
                  ? 'No necesitas gastar resina: lo que falta se consigue gratis (abajo).'
                  : schedule.finish == null
                  ? 'Con 180 de resina al día tardarías más de un año.'
                  : 'A este ritmo terminas el ${schedule.finish!.day}/${schedule.finish!.month}/${schedule.finish!.year} '
                        '(${schedule.finish!.difference(DateTime(today.year, today.month, today.day)).inDays + 1} días, '
                        '${formatNumber(schedule.totalResin)} de resina).',
              style: theme.textTheme.titleMedium,
            ),
            const Text(
              'Prioridad: primero el nivel del personaje, luego el arma y al final los talentos. '
              'Lo que solo se puede hacer ciertos días o una vez por semana va primero dentro de cada etapa. '
              'Las cantidades son promedios; actualiza tu inventario después de farmear y el plan se recalcula.',
            ),
            const SizedBox(height: 16),
            Text(
              'Hoy · ${weekdayNames[today.weekday - 1]}',
              style: theme.textTheme.titleMedium,
            ),
            if (schedule.days.isEmpty || schedule.days.first.runs.isEmpty)
              const Text('Hoy no hay nada que hacer con resina para esta build.'),
            if (schedule.days.isNotEmpty)
              for (final run in schedule.days.first.runs)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: done.contains(run.task.title),
                  onChanged: (v) => _toggle(run.task.title, v!),
                  secondary: materialIcon(byId[run.task.materialId]?.image),
                  title: Text('${run.task.title} × ${run.count}'),
                  subtitle: Text(
                    '${run.task.phase.label} · ${run.resin} de resina'
                    '${run.condensed > 0 ? ' (${run.condensed ~/ 40} concentrada)' : ''}',
                  ),
                ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Próximos días'),
              children: [
                for (final day in schedule.days.skip(1).take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${weekdayNames[day.date.weekday - 1]} ${day.date.day}/${day.date.month}',
                    ),
                    subtitle: Text(
                      day.runs.isEmpty
                          ? 'Nada pendiente con resina'
                          : day.runs
                                .map((r) => '${r.task.kind.label} × ${r.count}')
                                .join(' · '),
                    ),
                  ),
              ],
            ),
          ]),
          if (farm.free.isNotEmpty)
            _card('Sin gastar resina', [
              const Text('Esto se consigue explorando; márcalo cuando lo tengas.'),
              const SizedBox(height: 8),
              for (final task in farm.free)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: done.contains('free:${task.title}'),
                  onChanged: (v) => _toggle('free:${task.title}', v!),
                  secondary: materialIcon(byId[task.materialId]?.image),
                  title: Text(task.title),
                  subtitle: Text('Te faltan ${formatNumber(task.missing)}'),
                ),
              const Text(
                'Consejo: en la Tetera de la Serenidad puedes cambiar la moneda del reino '
                'por Mora, libros de EXP y Resina transitoria en la tienda de Tubby.',
              ),
            ]),
        ],
        _card(
          'Tu inventario',
          [
            const Text('Lo que pongas aquí se comparte con todas tus builds y con la calculadora.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, item) in characterExpItems.indexed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      materialIcon(byId[item.id]?.image),
                      const SizedBox(width: 6),
                      _numberField(books[i], item.label, width: 200),
                    ],
                  ),
                if (weapon != null)
                  for (final (i, item) in weaponExpItems.indexed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        materialIcon(byId[item.id]?.image),
                        const SizedBox(width: 6),
                        _numberField(ores[i], item.label, width: 200),
                      ],
                    ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    materialIcon(byId['material:202']?.image),
                    const SizedBox(width: 6),
                    _numberField(mora, 'Mora', width: 200),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final p in phases ?? <PhaseNeeds>[]) ...[
              Text(p.phase.label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final line in p.plan.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      materialIcon(byId[line.id]?.image),
                      SizedBox(width: 210, child: Text(byId[line.id]?.name ?? line.id)),
                      SizedBox(width: 110, child: Text('Necesitas ${formatNumber(line.needed)}')),
                      _numberField(_owned(line.id), 'Tienes', width: 100),
                      Text(
                        line.missing == 0 ? 'Listo' : 'Faltan ${formatNumber(line.missing)}',
                        style: line.missing == 0 ? good : bad,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _saveInventory,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar inventario'),
                ),
                if (notice != null) Text(notice!),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
