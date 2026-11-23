import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/catalog.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;
import '../data/build_repository.dart';
import '../domain/build.dart';

/// Picks a character and weapon and how far each one is now and should go.
class BuildEditorDialog extends ConsumerStatefulWidget {
  const BuildEditorDialog({required this.bundle, this.existing, super.key});
  final CatalogBundle bundle;
  final GenshinBuild? existing;
  @override
  ConsumerState<BuildEditorDialog> createState() => _BuildEditorDialogState();
}

class _LevelInput {
  _LevelInput(ProgressionState s)
    : level = TextEditingController(text: '${s.level}'),
      ascended =
          capsForLevel(s.level).length > 1 &&
          ProgressionRules.caps[s.ascension] != capsForLevel(s.level).first;
  final TextEditingController level;
  bool ascended;
}

class _BuildEditorDialogState extends ConsumerState<BuildEditorDialog> {
  CatalogRecord? character, weapon;
  late final _LevelInput charNow, charGoal, weaponNow, weaponGoal;
  late final List<TextEditingController> talentsNow, talentsGoal;
  late bool talentsOn;
  String? error;
  bool busy = false;

  static const _talentNames = [
    'Ataque normal',
    'Habilidad elemental',
    'Definitiva',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    final byId = {for (final r in widget.bundle.records) r.id: r};
    character = b == null ? null : byId[b.characterId];
    weapon = b?.weaponId == null ? null : byId[b!.weaponId];
    charNow = _LevelInput(
      b?.characterNow ?? const ProgressionState(level: 1, ascension: 0),
    );
    charGoal = _LevelInput(
      b?.characterGoal ?? const ProgressionState(level: 90, ascension: 6),
    );
    weaponNow = _LevelInput(
      b?.weaponNow ?? const ProgressionState(level: 1, ascension: 0),
    );
    weaponGoal = _LevelInput(
      b?.weaponGoal ?? const ProgressionState(level: 90, ascension: 6),
    );
    talentsNow = [
      for (final t in b?.characterNow.talents ?? const [1, 1, 1])
        TextEditingController(text: '$t'),
    ];
    talentsGoal = [
      for (final t in b?.characterGoal.talents ?? const [1, 10, 10])
        TextEditingController(text: '$t'),
    ];
    talentsOn = b?.talentsOn ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      charNow.level,
      charGoal.level,
      weaponNow.level,
      weaponGoal.level,
      ...talentsNow,
      ...talentsGoal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, String label) => int.tryParse(c.text.trim()) ??
      (throw CalculationException('$label: escribe un número.'));

  ProgressionState _state(_LevelInput input, String label, [List<int>? talents]) {
    final level = _int(input.level, label);
    return ProgressionState(
      level: level,
      ascension: ascensionFor(level, ascended: input.ascended),
      talents: talents ?? const [1, 1, 1],
    );
  }

  Future<void> _save() async {
    setState(() {
      error = null;
      busy = true;
    });
    try {
      require(character != null, 'Elige un personaje.');
      List<int> talents(List<TextEditingController> c, String label) => [
        for (var i = 0; i < 3; i++) _int(c[i], '${_talentNames[i]} ($label)'),
      ];
      final now = _state(charNow, 'Nivel actual', talentsOn ? talents(talentsNow, 'ahora') : const [1, 1, 1]);
      final goal = _state(charGoal, 'Nivel objetivo', talentsOn ? talents(talentsGoal, 'objetivo') : now.talents);
      final build = GenshinBuild(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        characterId: character!.id,
        weaponId: weapon?.id,
        characterNow: now,
        characterGoal: goal,
        weaponNow: _state(weaponNow, 'Nivel actual del arma'),
        weaponGoal: _state(weaponGoal, 'Nivel objetivo del arma'),
        talentsOn: talentsOn,
      );
      // Validate with the calculator before saving.
      final rules = await ref.read(progressionRulesProvider.future);
      calculateProgression(widget.bundle, character!, rules, build.characterNow, build.characterGoal);
      if (weapon != null) {
        calculateProgression(widget.bundle, weapon!, rules, build.weaponNow, build.weaponGoal);
      }
      final repo = ref.read(buildRepositoryProvider);
      await repo.save(build);
      String level(ProgressionState s) =>
          '${s.level}/${ProgressionRules.caps[s.ascension]}';
      final old = widget.existing;
      await repo.log(
        old == null
            ? 'Nueva build: ${character!.name}${weapon == null ? '' : ' + ${weapon!.name}'}'
                  ' (nivel ${level(now)} → ${level(goal)}).'
            : 'Progreso de ${character!.name}: nivel ${level(old.characterNow)} → ${level(now)}'
                  '${talentsOn ? ', talentos ${old.characterNow.talents.join('/')} → ${now.talents.join('/')}' : ''}'
                  '${weapon == null ? '' : '; ${weapon!.name} ${level(old.weaponNow)} → ${level(build.weaponNow)}'}.',
      );
      ref.invalidate(buildsProvider);
      ref.invalidate(historyProvider);
      if (mounted) Navigator.pop(context, build);
    } on CalculationException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudo guardar la build. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _picker(
    String label,
    Iterable<CatalogRecord> options,
    CatalogRecord? selected,
    ValueChanged<CatalogRecord?> onSelected,
  ) => Autocomplete<CatalogRecord>(
    key: ValueKey('$label-${selected?.id}'),
    initialValue: TextEditingValue(text: selected?.name ?? ''),
    displayStringForOption: (r) => r.name,
    optionsBuilder: (value) {
      final q = value.text.toLowerCase().trim();
      final list = options
          .where((r) => q.isEmpty || r.name.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    },
    onSelected: onSelected,
    fieldViewBuilder: (context, controller, focus, submit) => TextField(
      controller: controller,
      focusNode: focus,
      // Typing the full name counts as choosing it (handy on phones, where
      // people often skip tapping the suggestion).
      onChanged: (text) {
        final typed = text.trim().toLowerCase();
        final match = options
            .where((r) => r.name.toLowerCase() == typed)
            .firstOrNull;
        if (match != null && match.id != selected?.id) onSelected(match);
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: selected?.image == null
            ? const Icon(Icons.search)
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Image.network(
                  selected!.image!,
                  width: 32,
                  errorBuilder: (_, _, _) => const Icon(Icons.search),
                ),
              ),
        border: const OutlineInputBorder(),
      ),
    ),
    optionsViewBuilder: (context, select, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 420),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final r in options)
                ListTile(
                  dense: true,
                  leading: r.image == null
                      ? null
                      : Image.network(
                          r.image!,
                          width: 32,
                          errorBuilder: (_, _, _) => const SizedBox(width: 32),
                        ),
                  title: Text(r.name),
                  subtitle: Text(
                    [
                      if (r.rarity != null) '${r.rarity} ★',
                      ?r.progression?.element,
                      ?r.progression?.weaponType,
                    ].join(' · '),
                  ),
                  onTap: () => select(r),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _levelRow(String label, _LevelInput input) {
    final level = int.tryParse(input.level.text.trim());
    final caps = level == null ? <int>[] : capsForLevel(level);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: TextField(
            controller: input.level,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              suffixText: caps.isEmpty
                  ? null
                  : '/ ${input.ascended && caps.length > 1 ? caps[1] : caps.first}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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

  /// One line per talent: name · now → target (fits a phone screen).
  Widget _talentRow(int i) {
    Widget field(TextEditingController c, String label) => SizedBox(
      width: 68,
      child: TextField(
        key: ValueKey('talent-$i-$label'),
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: Text(_talentNames[i])),
        field(talentsNow[i], 'Ahora'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 16),
        ),
        field(talentsGoal[i], 'Meta'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final characters = widget.bundle.records.where(
      (r) =>
          r.kind == CatalogKind.character &&
          !r.pendingFields.contains('requirements'),
    );
    final weapons = widget.bundle.records.where(
      (r) =>
          r.kind == CatalogKind.weapon &&
          !r.pendingFields.contains('requirements') &&
          (r.rarity ?? 0) >= 3 &&
          (character == null ||
              r.progression?.weaponType == character!.progression?.weaponType),
    );
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nueva build' : 'Actualizar progreso'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige el personaje y su arma, y pon los niveles como los ves en '
                'el juego. Si está justo en un tope (20, 40, 50…), marca "Ya ascendido" '
                'si ya pasaste esa ascensión.',
              ),
              title('Personaje'),
              _picker('Busca el personaje', characters, character, (r) {
                setState(() {
                  character = r;
                  if (weapon?.progression?.weaponType != r?.progression?.weaponType) {
                    weapon = null;
                  }
                });
              }),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _levelRow('Nivel ahora', charNow),
                  _levelRow('Nivel objetivo', charGoal),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Subir talentos'),
                value: talentsOn,
                onChanged: (v) => setState(() => talentsOn = v!),
              ),
              if (talentsOn) ...[
                const Text('Niveles base, sin el +3 de las constelaciones.'),
                const SizedBox(height: 8),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _talentRow(i),
                  ),
              ],
              title('Arma (opcional)'),
              if (character == null)
                const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Elige primero el personaje',
                    helperText: 'Así solo verás armas del tipo que usa.',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                )
              else
                _picker(
                  'Busca un ${character!.progression?.weaponType.toLowerCase()}',
                  weapons,
                  weapon,
                  (r) => setState(() => weapon = r),
                ),
              if (weapon != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _levelRow('Nivel ahora', weaponNow),
                    _levelRow('Nivel objetivo', weaponGoal),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => weapon = null),
                  child: const Text('Quitar arma'),
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
          onPressed: busy ? null : _save,
          child: const Text('Guardar build'),
        ),
      ],
    );
  }
}
