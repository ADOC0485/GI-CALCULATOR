import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/calculator_fields.dart';
import '../../catalog/domain/catalog.dart';
import '../data/scenario_repository.dart';
import '../domain/progression_calculator.dart';

final progressionRulesProvider = FutureProvider(
  (ref) async => ProgressionRules(
    await rootBundle.loadString('assets/rules/progression-v1.json'),
  ),
);

const _talentNames = ['Ataque normal', 'Habilidad elemental', 'Definitiva'];
const _talentKeys = ['Ataque', 'Habilidad', 'Definitiva'];

/// Level caps a level can show in game: 50 can be 50/50 or 50/60.
List<int> capsForLevel(int level) => [
  for (var a = 0; a < ProgressionRules.caps.length; a++)
    if (level >= ProgressionRules.floors[a] && level <= ProgressionRules.caps[a])
      ProgressionRules.caps[a],
];

class ProgressionDialog extends ConsumerStatefulWidget {
  const ProgressionDialog({
    required this.bundle,
    required this.record,
    super.key,
  });
  final CatalogBundle bundle;
  final CatalogRecord record;
  @override
  ConsumerState<ProgressionDialog> createState() => _ProgressionDialogState();
}

class _Side {
  _Side(String level, this.cap, List<String> talents)
    : level = TextEditingController(text: level),
      talents = [for (final t in talents) TextEditingController(text: t)];
  final TextEditingController level;
  final List<TextEditingController> talents;
  int cap;
  void dispose() {
    level.dispose();
    for (final c in talents) {
      c.dispose();
    }
  }
}

class _ProgressionDialogState extends ConsumerState<ProgressionDialog> {
  final now = _Side('1', 20, ['1', '1', '1']);
  final goal = _Side('90', 90, ['1', '10', '10']);
  bool talentsOn = false;
  bool busy = false;
  String? notice;

  bool get isCharacter => widget.record.kind == CatalogKind.character;

  @override
  void dispose() {
    now.dispose();
    goal.dispose();
    super.dispose();
  }

  ProgressionState state(_Side side, String suffix) {
    final level = whole(side.level.text, 'Nivel $suffix');
    final caps = capsForLevel(level);
    require(caps.isNotEmpty, 'Nivel $suffix: debe estar entre 1 y 90.');
    final cap = caps.contains(side.cap) ? side.cap : caps.first;
    return ProgressionState(
      level: level,
      ascension: ProgressionRules.caps.indexOf(cap),
      talents: talentsOn && isCharacter
          ? [
              for (var i = 0; i < 3; i++)
                whole(side.talents[i].text, '${_talentNames[i]} ($suffix)'),
            ]
          : const [1, 1, 1],
    );
  }

  void changed() => setState(() => notice = null);

  Map<String, String> _fields() => {
    for (final (side, suffix) in [(now, 'actual'), (goal, 'objetivo')]) ...{
      'Nivel $suffix': side.level.text,
      'Tope $suffix': '${side.cap}',
      for (var i = 0; i < 3; i++)
        '${_talentKeys[i]} $suffix': side.talents[i].text,
    },
    'Subir talentos': talentsOn ? 'sí' : 'no',
  };

  void _restore(Map<String, dynamic> values) {
    for (final (side, suffix) in [(now, 'actual'), (goal, 'objetivo')]) {
      final level = values['Nivel $suffix'];
      if (level is String) side.level.text = level;
      final cap = int.tryParse('${values['Tope $suffix']}');
      // Scenarios saved before this screen stored the ascension number.
      final ascension = int.tryParse('${values['Ascensión $suffix']}');
      if (cap != null) {
        side.cap = cap;
      } else if (ascension != null && ascension >= 0 && ascension <= 6) {
        side.cap = ProgressionRules.caps[ascension];
      }
      for (var i = 0; i < 3; i++) {
        final talent = values['${_talentKeys[i]} $suffix'];
        if (talent is String) side.talents[i].text = talent;
      }
    }
    talentsOn = values['Subir talentos'] == 'sí' ||
        (values['Subir talentos'] == null &&
            values['Ataque objetivo'] is String &&
            [for (final k in _talentKeys) values['$k objetivo']].any(
              (v) => v != '1',
            ));
  }

  Future<void> storage(bool save) async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final repo = ref.read(scenarioRepositoryProvider);
      final key = 'progression:${widget.record.id}';
      if (save) {
        await repo.save(key, {
          'schema': 2,
          'catalogVersion': widget.bundle.version,
          'fields': _fields(),
        });
        notice = 'Escenario guardado en este equipo.';
      } else {
        final stored = await repo.load(key);
        if (!mounted) return;
        if (stored == null) {
          notice = 'Todavía no hay un escenario guardado.';
        } else {
          _restore(stored['fields'] as Map<String, dynamic>);
          notice = stored['catalogVersion'] == widget.bundle.version
              ? 'Escenario recuperado y recalculado.'
              : 'El catálogo cambió: escenario recalculado con la versión activa.';
        }
      }
    } catch (_) {
      notice =
          'No se pudo guardar o recuperar el escenario. Tus datos anteriores se conservan.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _levelCard(BuildContext context, _Side side, bool target) {
    final theme = Theme.of(context);
    final level = int.tryParse(side.level.text.trim());
    final caps = level == null ? <int>[] : capsForLevel(level);
    if (caps.isNotEmpty && !caps.contains(side.cap)) side.cap = caps.first;
    final ascension = caps.isEmpty
        ? null
        : ProgressionRules.caps.indexOf(side.cap);
    final suffix = target ? 'objetivo' : 'actual';
    return SizedBox(
      width: 340,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                target ? 'Objetivo' : 'Como lo tienes ahora',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      key: ValueKey('level-$suffix'),
                      controller: side.level,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Nivel $suffix',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => changed(),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Text('/', style: TextStyle(fontSize: 20)),
                  ),
                  Expanded(
                    child: caps.length > 1
                        ? DropdownButtonFormField<int>(
                            key: ValueKey('cap-$suffix-${side.cap}-$caps'),
                            initialValue: side.cap,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '¿Ya ascendido?',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final (i, cap) in caps.indexed)
                                DropdownMenuItem(
                                  value: cap,
                                  child: Text(
                                    i == 0
                                        ? '$cap · sin ascender'
                                        : '$cap · ya ascendido',
                                  ),
                                ),
                            ],
                            onChanged: (cap) => setState(() {
                              side.cap = cap!;
                              notice = null;
                            }),
                          )
                        : InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Nivel máximo',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(caps.isEmpty ? '—' : '${caps.first}'),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (ascension != null)
                Semantics(
                  label: 'Ascensión $ascension de 6',
                  child: Row(
                    children: [
                      for (var i = 0; i < 6; i++)
                        Icon(
                          i < ascension ? Icons.star : Icons.star_border,
                          size: 20,
                          color: i < ascension
                              ? Colors.amber
                              : theme.colorScheme.outline,
                        ),
                      const SizedBox(width: 8),
                      Flexible(child: Text('Ascensión $ascension/6')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _talentTable(BuildContext context) {
    Widget cell(TextEditingController c, String label) => SizedBox(
      width: 90,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => changed(),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Niveles base, sin contar el +3 de las constelaciones (1 a 10).',
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: 160, child: Text(_talentNames[i])),
                    cell(now.talents[i], 'Ahora'),
                    const Icon(Icons.arrow_forward, size: 18),
                    cell(goal.talents[i], 'Objetivo'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesValue = ref.watch(progressionRulesProvider);
    ProgressionResult? result;
    String? error;
    final rules = rulesValue.asData?.value;
    if (rules != null) {
      try {
        result = calculateProgression(
          widget.bundle,
          widget.record,
          rules,
          state(now, 'actual'),
          state(goal, 'objetivo'),
        );
      } on CalculationException catch (e) {
        error = e.message;
      }
    }
    final names = {for (final r in widget.bundle.records) r.id: r.name};
    return AlertDialog(
      title: Text('Calcular · ${widget.record.name}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pon el nivel tal como lo ves en el juego, por ejemplo 50/50. '
                'Si está justo en un tope, indica si ya lo ascendiste.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _levelCard(context, now, false),
                  _levelCard(context, goal, true),
                ],
              ),
              if (isCharacter) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: talentsOn,
                  title: const Text('Subir talentos'),
                  onChanged: (v) => setState(() {
                    talentsOn = v!;
                    notice = null;
                  }),
                ),
                if (talentsOn) _talentTable(context),
              ],
              const SizedBox(height: 16),
              if (rulesValue.isLoading) const LinearProgressIndicator(),
              if (rulesValue.hasError)
                const Text('No se pudieron cargar las reglas de cálculo.'),
              if (error != null)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (result != null) ...[
                Text(
                  'EXP necesaria: ${result.experience}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Mora de mejora: ${result.levelingMora} · incluida en el total de Mora de abajo.',
                ),
                const SizedBox(height: 12),
                Text(
                  isCharacter
                      ? 'Libros de EXP (redondeados en cada tope de ascensión):'
                      : 'Minerales de refinamiento (redondeados en cada tope de ascensión; sin usar armas como alimento):',
                ),
                for (final entry in result.expItems.entries)
                  Text('${entry.key}: ${entry.value}'),
                Text('EXP que sobra: ${result.surplus}'),
                const SizedBox(height: 16),
                Text(
                  talentsOn && isCharacter
                      ? 'Materiales totales · ascensión + talentos + Mora'
                      : 'Materiales totales · ascensión + Mora',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result.materials.isEmpty)
                  const Text('Tu progreso ya coincide con el objetivo.'),
                for (final entry in result.materials.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${names[entry.key] ?? entry.key}: ${entry.value}',
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Catálogo ${widget.bundle.version}. Fuentes comunitarias; sin descontar inventario.',
                ),
              ],
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(notice!),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => storage(false),
          child: const Text('Recuperar escenario'),
        ),
        FilledButton(
          onPressed: busy || result == null ? null : () => storage(true),
          child: const Text('Guardar escenario'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
