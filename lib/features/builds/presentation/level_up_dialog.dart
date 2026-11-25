import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/catalog.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;
import '../data/build_repository.dart';
import '../domain/build.dart';
import '../domain/build_step.dart';
import 'build_page.dart' show formatNumber;

/// "Subir": asks how far the build went in the game (suggesting the most the
/// free materials allow), warns when it takes what a build with more
/// priority reserved, and takes the cost out of the inventory.
/// Returns the saved build, or null when nothing changed.
Future<GenshinBuild?> showLevelUp(
  BuildContext context,
  WidgetRef ref, {
  required CatalogBundle bundle,
  required GenshinBuild build,
}) async {
  final repo = ref.read(buildRepositoryProvider);
  final rules = await ref.read(progressionRulesProvider.future);
  final inventory = await repo.inventory();
  final builds = await ref.read(buildsProvider.future);
  final index = builds.indexWhere((b) => b.id == build.id);
  final above = index < 0 ? builds : builds.sublist(0, index);
  final free = reserveInventory(
    bundle: bundle,
    rules: rules,
    builds: above,
    inventory: inventory,
  ).left;
  final suggested = suggestStep(
    bundle: bundle,
    rules: rules,
    build: build,
    pool: free,
  );
  if (!context.mounted) return null;
  return showDialog<GenshinBuild>(
    context: context,
    builder: (_) => _LevelUpDialog(
      bundle: bundle,
      rules: rules,
      build: build,
      builds: builds,
      inventory: inventory,
      suggested: suggested,
    ),
  );
}

class _Level {
  _Level(ProgressionState s)
    : text = TextEditingController(text: '${s.level}'),
      ascended =
          capsForLevel(s.level).length > 1 &&
          ProgressionRules.caps[s.ascension] != capsForLevel(s.level).first;
  final TextEditingController text;
  bool ascended;
}

class _LevelUpDialog extends ConsumerStatefulWidget {
  const _LevelUpDialog({
    required this.bundle,
    required this.rules,
    required this.build,
    required this.builds,
    required this.inventory,
    required this.suggested,
  });
  final CatalogBundle bundle;
  final ProgressionRules rules;
  final GenshinBuild build;
  final List<GenshinBuild> builds;
  final Inventory inventory;
  final StepTarget suggested;

  @override
  ConsumerState<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends ConsumerState<_LevelUpDialog> {
  late final _Level character = _Level(
    widget.suggested.character ?? widget.build.characterNow,
  );
  late final _Level weapon = _Level(
    widget.suggested.weapon ?? widget.build.weaponNow,
  );
  late final talents = [
    for (final t
        in (widget.suggested.character ?? widget.build.characterNow).talents)
      TextEditingController(text: '$t'),
  ];
  late final byId = {for (final r in widget.bundle.records) r.id: r};
  String? error;
  bool busy = false;

  static const _talentNames = [
    'Ataque normal',
    'Habilidad elemental',
    'Definitiva',
  ];

  GenshinBuild get item => widget.build;

  bool get _nothingSuggested {
    final s = widget.suggested;
    bool same(ProgressionState? a, ProgressionState b) =>
        a == null ||
        (a.level == b.level &&
            a.ascension == b.ascension &&
            [for (var i = 0; i < 3; i++) a.talents[i] == b.talents[i]]
                .every((v) => v));
    return same(s.character, item.characterNow) &&
        same(s.weapon, item.weaponNow);
  }

  @override
  void dispose() {
    for (final c in [character.text, weapon.text, ...talents]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, String label) =>
      int.tryParse(c.text.trim()) ??
      (throw CalculationException('$label: escribe un número.'));

  ProgressionState _state(_Level input, String label, List<int> talents) {
    final level = _int(input.text, label);
    return ProgressionState(
      level: level,
      ascension: ascensionFor(level, ascended: input.ascended),
      talents: talents,
    );
  }

  void _notPast(ProgressionState to, ProgressionState goal, String what) {
    require(
      to.level <= goal.level && to.ascension <= goal.ascension,
      '$what no puede pasar de la meta (${goal.level}).',
    );
  }

  String _itemName(String id) =>
      id == 'exp' ? 'EXP' : byId[id]?.name ?? id.replaceFirst('material:', '');

  String _items(Map<String, int> items) => [
    for (final e in items.entries)
      '${_itemName(e.key)} × ${formatNumber(e.value)}',
  ].join('\n');

  Future<bool> _ask(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              key: const ValueKey('level-up-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, dejarlo así'),
            ),
            FilledButton(
              key: const ValueKey('level-up-anyway'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirm() async {
    setState(() {
      error = null;
      busy = true;
    });
    try {
      final now = item.characterNow;
      ProgressionState? c, w;
      if (item.hasCharacter) {
        final t = item.talentsUsed
            ? [for (var i = 0; i < 3; i++) _int(talents[i], _talentNames[i])]
            : now.talents;
        c = _state(character, 'Nivel del personaje', t);
        _notPast(c, item.characterGoal, 'El nivel');
        for (var i = 0; i < 3 && item.talentsUsed; i++) {
          require(
            t[i] <= item.characterGoal.talents[i],
            '${_talentNames[i]} no puede pasar de la meta '
            '(${item.characterGoal.talents[i]}).',
          );
        }
        calculateProgression(
          widget.bundle,
          byId[item.characterId]!,
          widget.rules,
          now,
          c,
        );
      }
      if (item.hasWeapon) {
        w = _state(weapon, 'Nivel del arma', const [1, 1, 1]);
        _notPast(w, item.weaponGoal, 'El arma');
        calculateProgression(
          widget.bundle,
          byId[item.weaponId]!,
          widget.rules,
          item.weaponNow,
          w,
        );
      }
      final target = StepTarget(character: c, weapon: w);
      final check = checkStep(
        bundle: widget.bundle,
        rules: widget.rules,
        build: item,
        target: target,
        inventory: widget.inventory,
        builds: widget.builds,
      );
      final moved = target.applyTo(item);
      final changed =
          !check.nothing ||
          moved.characterNow.level != now.level ||
          moved.characterNow.ascension != now.ascension ||
          moved.weaponNow.level != item.weaponNow.level ||
          moved.weaponNow.ascension != item.weaponNow.ascension ||
          [
            for (var i = 0; i < 3; i++)
              moved.characterNow.talents[i] != now.talents[i],
          ].any((v) => v);
      require(changed, 'No cambiaste nada: sube algún nivel o talento.');

      if (check.short.isNotEmpty &&
          !await _ask(
            'Según tu inventario no te alcanza',
            'Te faltan:\n${_items(check.short)}\n\n'
                'Si en el juego sí lo subiste (quizá tu inventario aquí no está al día), '
                'se descuenta lo que tienes y esos materiales quedan en 0.',
            'Sí, lo subí',
          )) {
        return;
      }
      if (check.takenFrom.isNotEmpty) {
        final names = {for (final b in widget.builds) b.id: b.name(byId)};
        final position = {
          for (final (i, b) in widget.builds.indexed) b.id: i + 1,
        };
        final body = [
          for (final e in check.takenFrom.entries)
            'Reservado para ${names[e.key]} (prioridad ${position[e.key]}):\n'
                '${_items(e.value)}',
        ].join('\n\n');
        if (!mounted ||
            !await _ask(
              'Esto usa materiales de otra build',
              '$body\n\nEsas builds tienen más prioridad. Si subes esta, '
                  'tendrán que volver a conseguirlos.',
              'Subir igual',
            )) {
          return;
        }
      }

      final repo = ref.read(buildRepositoryProvider);
      await repo.setOwned({
        for (final e in check.used.entries)
          e.key: (widget.inventory.owned(e.key) - e.value).clamp(0, 1 << 40),
      });
      var saved = moved;
      if (saved.atGoal) saved = saved.copyWith(finishedAt: DateTime.now());
      await repo.save(saved);
      String level(ProgressionState s) =>
          '${s.level}/${ProgressionRules.caps[s.ascension]}';
      await repo.log(
        'Subiste ${item.name(byId)}: ${[if (c != null) 'nivel ${level(now)} → ${level(c)}', if (c != null && item.talentsUsed) 'talentos ${now.talents.join('/')} → ${c.talents.join('/')}', if (w != null) 'arma ${level(item.weaponNow)} → ${level(w)}'].join(', ')}. Se descontó del inventario.',
      );
      if (saved.finished) {
        await repo.log('¡Build terminada! ${item.name(byId)}.');
      }
      ref
        ..invalidate(buildsProvider)
        ..invalidate(finishedBuildsProvider)
        ..invalidate(inventoryProvider)
        ..invalidate(historyProvider);
      if (mounted) Navigator.pop(context, saved);
    } on CalculationException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudo subir. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _levelField(String label, _Level input, int goal, String key) {
    final level = int.tryParse(input.text.text.trim());
    final caps = level == null ? <int>[] : capsForLevel(level);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 170,
          child: TextField(
            key: ValueKey(key),
            controller: input.text,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              helperText: 'Meta: $goal',
              suffixText: caps.isEmpty
                  ? null
                  : '/ ${input.ascended && caps.length > 1 ? caps[1] : caps.first}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => error = null),
          ),
        ),
        if (caps.length > 1)
          FilterChip(
            label: const Text('Ya ascendido'),
            selected: input.ascended,
            onSelected: (v) => setState(() => input.ascended = v),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    return AlertDialog(
      title: Text('Subir ${item.name(byId)}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nothingSuggested
                    ? 'Con tus materiales libres todavía no alcanza para subir nada. '
                          'Si igual lo subiste en el juego, pon hasta dónde llegó.'
                    : 'Con tus materiales libres te alcanza hasta aquí (sin tocar lo '
                          'reservado para builds con más prioridad). Cámbialo si en el '
                          'juego lo subiste distinto.',
              ),
              if (item.hasCharacter) ...[
                title(byId[item.characterId]?.name ?? 'Personaje'),
                _levelField(
                  'Nivel',
                  character,
                  item.characterGoal.level,
                  'level-up-character',
                ),
                if (item.talentsUsed) ...[
                  const SizedBox(height: 12),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(_talentNames[i])),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              key: ValueKey('level-up-talent-$i'),
                              controller: talents[i],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                helperText:
                                    'Meta ${item.characterGoal.talents[i]}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
              if (item.hasWeapon) ...[
                title(byId[item.weaponId]?.name ?? 'Arma'),
                _levelField(
                  'Nivel',
                  weapon,
                  item.weaponGoal.level,
                  'level-up-weapon',
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('level-up-confirm'),
          onPressed: busy ? null : _confirm,
          child: const Text('Subir y descontar'),
        ),
      ],
    );
  }
}
