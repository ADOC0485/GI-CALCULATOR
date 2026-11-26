import 'package:flutter/material.dart';

import '../../resin/wallet.dart';
import '../../tasks/task_completion.dart';
import '../../tasks/task_log.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/page_frame.dart';
import '../../agenda/agenda_page.dart';
import '../../builds/data/build_repository.dart';
import '../../builds/domain/build.dart';
import '../../builds/presentation/build_editor_dialog.dart';
import '../../builds/presentation/build_page.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;
import '../../resin/resin_bar.dart';
import '../../resin/resin_state.dart';
import '../../profiles/profile.dart';
import '../../profiles/profile_dialog.dart';
import '../../profiles/profiles_card.dart';
import '../../settings/presentation/theme_toggle_button.dart';

/// Home: pending builds with their progress, and what to do today.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(catalogProvider).asData?.value;
    final rules = ref.watch(progressionRulesProvider).asData?.value;
    final builds = ref.watch(buildsProvider).asData?.value;
    final inventory = ref.watch(inventoryProvider).asData?.value;
    final resin = ref.watch(resinProvider).asData?.value;
    final profile = ref.watch(profilesProvider).asData?.value.active;
    final now = DateTime.now();
    // Game day of the profile's server (it changes at 04:00 there).
    final today = gameDay(now, ref.watch(activeServerProvider));
    AgendaPlan? plan;
    if (bundle != null &&
        rules != null &&
        builds != null &&
        inventory != null &&
        builds.isNotEmpty) {
      try {
        plan = planAgenda(
          bundle: bundle,
          rules: rules,
          builds: builds,
          inventory: inventory,
          start: today,
          startResin: resin?.normalAt(now) ?? 180,
          startCondensed: resin?.condensed ?? 0,
          weeklyDoneThisWeek:
              ref.watch(weeklyBossesDoneProvider).asData?.value ?? const {},
        );
      } on CalculationException {
        plan = null;
      }
    }
    final buildsCard = _BuildsCard(bundle: bundle, builds: builds, plan: plan);
    final todayCard = _TodayCard(bundle: bundle, plan: plan, today: today);
    return PageFrame(
      title: profile?.greeting ?? 'Tu próxima aventura',
      subtitle: profile == null
          ? 'Tus builds pendientes y lo que toca hacer hoy.'
          : '${profileDetails(profile)} · Tus builds pendientes y lo que toca hacer hoy.',
      action: const ThemeToggleButton(),
      children: [
        if (profile != null &&
            profile.gender == null &&
            profile.avatarId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProfileAvatar(profile: profile),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Personaliza tu perfil: tu nombre, servidor, nivel de mundo, '
                              'AR y tu personaje favorito como avatar.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => ProfileDialog(existing: profile),
                      ),
                      child: const Text('Personalizar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 820
              ? Column(
                  children: [buildsCard, const SizedBox(height: 16), todayCard],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: buildsCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: todayCard),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/characters'),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Explorar catálogo'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/agenda'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Ver la semana'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BuildsCard extends ConsumerWidget {
  const _BuildsCard({
    required this.bundle,
    required this.builds,
    required this.plan,
  });
  final CatalogBundle? bundle;
  final List<GenshinBuild>? builds;
  final AgendaPlan? plan;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final limit = await ref.read(buildLimitProvider.future);
    if (!context.mounted) return;
    if ((builds?.length ?? 0) >= limit) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Ya tienes $limit builds en proceso'),
          content: const Text(
            'Es el máximo para que los materiales no se repartan entre demasiados. '
            'Termina o borra una, o cambia el límite en Ajustes (no recomendado).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ir a Ajustes'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) context.go('/settings');
      return;
    }
    final created = await showDialog<GenshinBuild>(
      context: context,
      builder: (_) => BuildEditorDialog(bundle: bundle!),
    );
    if (created != null && context.mounted) {
      context.go('/build/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final byId = {
      for (final r in bundle?.records ?? const <CatalogRecord>[]) r.id: r,
    };
    final list = builds;
    final limit = ref.watch(buildLimitProvider).asData?.value;
    Future<void> move(GenshinBuild b, {required bool up}) async {
      await ref.read(buildRepositoryProvider).move(b.id, up: up);
      ref.invalidate(buildsProvider);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Tus builds',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (list != null && limit != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${list.length}/$limit',
                        key: const ValueKey('builds-count'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
                FilledButton.icon(
                  key: const ValueKey('add-build'),
                  onPressed: bundle == null ? null : () => _add(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir build'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list == null)
              const LinearProgressIndicator()
            else if (list.isEmpty)
              const Text(
                'Aún no tienes builds en proceso. Añade un personaje, un arma o los '
                'dos y te diremos qué te falta y cómo repartir la resina cada día.',
              )
            else ...[
              if (list.length > 1)
                Text(
                  'La de arriba tiene prioridad: se queda primero con los materiales. '
                  'Muévelas con las flechas.',
                  style: theme.textTheme.bodySmall,
                ),
              for (final (i, b) in list.indexed)
                _BuildRow(
                  item: b,
                  character: b.characterId == null ? null : byId[b.characterId],
                  weapon: b.weaponId == null ? null : byId[b.weaponId],
                  progress: plan?.progress[b.id],
                  finish: plan?.finishByBuild[b.owner(byId)],
                  onUp: i == 0 ? null : () => move(b, up: true),
                  onDown: i == list.length - 1
                      ? null
                      : () => move(b, up: false),
                  showArrows: list.length > 1,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({
    required this.item,
    required this.character,
    required this.weapon,
    required this.progress,
    required this.finish,
    this.onUp,
    this.onDown,
    this.showArrows = false,
  });
  final GenshinBuild item;
  final CatalogRecord? character, weapon;
  final BuildProgress? progress;
  final DateTime? finish;
  final VoidCallback? onUp, onDown;
  final bool showArrows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    final complete =
        p != null && p.fraction >= 1 && p.expMissing == 0 && p.moraMissing == 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/build/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (showArrows)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('up-${item.id}'),
                    tooltip: 'Más prioridad',
                    visualDensity: VisualDensity.compact,
                    onPressed: onUp,
                    icon: const RotatedBox(
                      quarterTurns: 3,
                      child: Icon(Icons.chevron_right),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('down-${item.id}'),
                    tooltip: 'Menos prioridad',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDown,
                    icon: const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            if (character != null)
              materialIcon(character?.image, size: 48)
            else
              materialIcon(weapon?.image, size: 48),
            if (character != null && weapon != null) ...[
              const SizedBox(width: 4),
              materialIcon(weapon!.image, size: 36),
            ],
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            if (item.hasCharacter)
                              character?.name ?? item.characterId!,
                            if (item.hasWeapon) weapon?.name ?? item.weaponId!,
                          ].join(' + '),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        p == null ? '—' : '${p.percent} %',
                        key: ValueKey('progress-${item.id}'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: p?.fraction ?? 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (item.hasCharacter)
                        'Nivel ${item.characterNow.level} → ${item.characterGoal.level}'
                      else
                        'Arma ${item.weaponNow.level} → ${item.weaponGoal.level}',
                      if (item.talentsUsed)
                        'Talentos ${item.characterNow.talents.join('/')} → ${item.characterGoal.talents.join('/')}',
                      if (p != null)
                        '${formatNumber(p.have)} de ${formatNumber(p.needed)} materiales',
                      if (complete)
                        '¡Tienes todo!'
                      else if (finish != null)
                        'Lista el ${finish!.day}/${finish!.month}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Daily routine plus today's resin plan, with a checklist saved per day.
class _TodayCard extends ConsumerStatefulWidget {
  const _TodayCard({
    required this.bundle,
    required this.plan,
    required this.today,
  });
  final CatalogBundle? bundle;
  final AgendaPlan? plan;
  final DateTime today;

  @override
  ConsumerState<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends ConsumerState<_TodayCard> {
  static const _routine = [
    (
      TaskRef(
        key: 'rutina|daily',
        label: 'Encargos diarios y recompensa de la Asociación',
        primogems: Wallet.commissionPrimogems,
        commission: true,
      ),
      Icons.assignment_turned_in_outlined,
    ),
    (
      TaskRef(
        key: 'rutina|welkin',
        label: 'Reclamar la Bendición lunar (si la tienes)',
        primogems: Wallet.welkinPrimogems,
      ),
      Icons.brightness_3_outlined,
    ),
    (
      TaskRef(
        key: 'rutina|teapot',
        label: 'Tetera: moneda del reino y confianza de Tubby',
      ),
      Icons.local_cafe_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {
      for (final r in widget.bundle?.records ?? const <CatalogRecord>[])
        r.id: r,
    };
    final done =
        ref.watch(doneTodayProvider).asData?.value ?? const <DoneTask>[];
    final doneKeys = {for (final t in done) t.key};
    final runs = widget.plan?.schedule.days.firstOrNull?.runs ?? const [];
    final shown = {
      for (final (task, _) in _routine) task.key,
      for (final run in runs) TaskRef.runKey(run.task),
    };
    final extraDone = done.where((t) => !shown.contains(t.key)).length;
    final total = shown.length + extraDone;
    final checked = shown.where(doneKeys.contains).length + extraDone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hoy · ${weekdayNames[widget.today.weekday - 1]}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text('$checked/$total', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final (task, icon) in _routine)
              CheckboxListTile(
                key: ValueKey('today-${task.key.split('|').last}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: doneKeys.contains(task.key),
                onChanged: (_) => toggleTask(context, ref, task, done),
                secondary: Icon(icon),
                title: Text(task.label),
                subtitle: task.primogems > 0
                    ? Text(
                        task.commission
                            ? '+${task.primogems} Protogemas y la Mora de los encargos'
                            : '+${task.primogems} Protogemas',
                      )
                    : null,
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gastar la resina en',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ResinDialog(),
                  ),
                  icon: const Icon(Icons.nightlight_round, size: 18),
                  label: const Text('Editar resina'),
                ),
              ],
            ),
            if (widget.plan == null)
              const Text('Añade una build para saber en qué gastar tu resina.')
            else if (runs.isEmpty)
              const Text(
                'Nada pendiente con resina hoy: aprovecha para explorar.',
              )
            else
              for (final run in runs)
                CheckboxListTile(
                  key: ValueKey(
                    'today-run-${run.task.owner}-${run.task.title}',
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: doneKeys.contains(TaskRef.runKey(run.task)),
                  onChanged: (_) =>
                      toggleTask(context, ref, TaskRef.run(run), done),
                  secondary: materialIcon(byId[run.task.materialId]?.image),
                  title: Text('${run.task.title} × ${run.count}'),
                  subtitle: Text(
                    '${run.task.owner} · ${run.resin} de resina'
                    '${run.condensed > 0 ? ' (${run.condensedCount} concentrada)' : ''}',
                  ),
                ),
            DoneTodayTiles(shown: shown),
          ],
        ),
      ),
    );
  }
}
