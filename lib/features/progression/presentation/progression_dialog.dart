import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/calculator_fields.dart';
import '../../catalog/domain/catalog.dart';
import '../data/scenario_repository.dart';
import '../domain/inventory_plan.dart';
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
  final books = List.generate(3, (_) => TextEditingController());
  final moraOwned = TextEditingController();
  final owned = <String, TextEditingController>{};
  final expRate = TextEditingController(
    text: '${const LeyLineRates().experience}',
  );
  final moraRate = TextEditingController(text: '${const LeyLineRates().mora}');

  static const inventoryKey = 'inventario';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  /// Inventory is shared by every character and weapon on this device.
  Future<void> _loadInventory() async {
    try {
      final stored = await ref
          .read(scenarioRepositoryProvider)
          .load(inventoryKey);
      if (!mounted || stored == null) return;
      setState(() => _restoreInventory(stored));
    } catch (_) {
      // A missing or unreadable inventory just starts empty.
    }
  }

  TextEditingController _owned(String id) =>
      owned.putIfAbsent(id, TextEditingController.new);

  String get _booksKey => isCharacter ? 'booksCharacter' : 'booksWeapon';

  Map<String, Object?> _inventory() => {
    'schema': 1,
    'materials': {
      for (final e in owned.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    },
    _booksKey: [for (final b in books) b.text.trim()],
    'mora': moraOwned.text.trim(),
    'expRate': expRate.text.trim(),
    'moraRate': moraRate.text.trim(),
  };

  void _restoreInventory(Map<String, dynamic> values) {
    final materials = values['materials'];
    if (materials is Map) {
      materials.forEach((id, v) {
        if (id is String && v is String) _owned(id).text = v;
      });
    }
    final stored = values[_booksKey];
    if (stored is List) {
      for (var i = 0; i < books.length && i < stored.length; i++) {
        if (stored[i] is String) books[i].text = stored[i] as String;
      }
    }
    for (final (key, controller) in [
      ('mora', moraOwned),
      ('expRate', expRate),
      ('moraRate', moraRate),
    ]) {
      final v = values[key];
      if (v is String && v.isNotEmpty) controller.text = v;
    }
  }

  int _count(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  bool get isCharacter => widget.record.kind == CatalogKind.character;

  @override
  void dispose() {
    now.dispose();
    goal.dispose();
    for (final c in [...books, moraOwned, expRate, moraRate, ...owned.values]) {
      c.dispose();
    }
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
        final previous = await repo.load(inventoryKey) ?? {};
        await repo.save(inventoryKey, {...previous, ..._inventory()});
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

  Widget _numberField(
    TextEditingController c,
    String label, {
    double width = 130,
    Key? key,
  }) => SizedBox(
    width: width,
    child: TextField(
      key: key,
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => changed(),
    ),
  );

  static String _n(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      );

  Widget _results(BuildContext context, ProgressionResult result) {
    final theme = Theme.of(context);
    final names = {for (final r in widget.bundle.records) r.id: r.name};
    final items = isCharacter ? characterExpItems : weaponExpItems;
    InventoryPlan? plan;
    String? planError;
    try {
      plan = planInventory(
        bundle: widget.bundle,
        record: widget.record,
        result: result,
        ownedBooks: [for (final b in books) _count(b)],
        ownedMaterials: {
          for (final id in result.materials.keys) id: _count(_owned(id)),
        },
        ownedMora: _count(moraOwned),
        rates: LeyLineRates(
          experience: _count(expRate),
          mora: _count(moraRate),
        ),
      );
    } on CalculationException catch (e) {
      planError = e.message;
    }
    final good = TextStyle(color: theme.colorScheme.primary);
    final bad = TextStyle(color: theme.colorScheme.error);
    final resin = LeyLineRates.resinPerRun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.materials.isEmpty && result.experience == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Tu progreso ya coincide con el objetivo.'),
          ),
        _section(
          context,
          isCharacter ? 'Nivel · libros de EXP' : 'Nivel · minerales de mejora',
          [
            Text(
              'EXP necesaria: ${_n(result.experience)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              isCharacter
                  ? '¿Cuántos libros tienes? Déjalo vacío si no tienes.'
                  : '¿Cuántos minerales tienes? Déjalo vacío si no tienes.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < items.length; i++)
                  _numberField(
                    books[i],
                    items[i].label,
                    width: 230,
                    key: ValueKey('book-$i'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (plan != null) ...[
              Text(
                'Con lo que tienes: ${_n(plan.expOwned)} de EXP · llegas a nivel ${plan.levelWithOwned}',
              ),
              if (plan.expMissing == 0)
                Text('¡Te alcanza para todo el nivel!', style: good)
              else ...[
                Text('Te faltan ${_n(plan.expMissing)} de EXP:', style: bad),
                for (final e in plan.booksToFarm.entries)
                  Text('• ${e.key}: ${_n(e.value)}'),
                if (isCharacter)
                  Text(
                    '≈ ${plan.expRuns} líneas ley de EXP (${plan.expRuns * resin} de resina)',
                    style: theme.textTheme.titleSmall,
                  ),
              ],
            ],
          ],
        ),
        _section(context, 'Mora', [
          _numberField(
            moraOwned,
            'Mora que tienes',
            width: 230,
            key: const ValueKey('mora-owned'),
          ),
          const SizedBox(height: 12),
          if (plan != null) ...[
            Text(
              'Necesitas ${_n(plan.moraTotal)}: subir nivel ${_n(result.levelingMora)}'
              ', ascensiones${talentsOn && isCharacter ? ' y talentos' : ''}'
              '${plan.craftingMora > 0 ? ', más ${_n(plan.craftingMora)} para convertir materiales' : ''}.',
            ),
            if (plan.moraMissing == 0)
              Text('¡Te alcanza la Mora!', style: good)
            else
              Text(
                'Te faltan ${_n(plan.moraMissing)} · ≈ ${plan.moraRuns} líneas ley de Mora (${plan.moraRuns * resin} de resina)',
                style: bad,
              ),
          ],
        ]),
        _section(context, 'Materiales', [
          const Text(
            'Pon cuántos tienes de cada uno. Si te sobran del nivel inferior, '
            'se usan convirtiendo 3 en 1, como en la alquimia.',
          ),
          const SizedBox(height: 12),
          if (plan != null)
            for (final line in plan.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    SizedBox(width: 230, child: Text(names[line.id] ?? line.id)),
                    SizedBox(
                      width: 110,
                      child: Text('Necesitas ${_n(line.needed)}'),
                    ),
                    _numberField(
                      _owned(line.id),
                      'Tienes',
                      width: 100,
                      key: ValueKey('owned-${line.id}'),
                    ),
                    if (line.missing == 0)
                      Text(
                        line.crafted > 0
                            ? 'Listo (${line.crafted} convirtiendo)'
                            : 'Listo',
                        style: good,
                      )
                    else
                      Text(
                        'Faltan ${_n(line.missing)}'
                        '${line.crafted > 0 ? ' (ya cuenta ${line.crafted} convirtiendo)' : ''}',
                        style: bad,
                      ),
                  ],
                ),
              ),
        ]),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Ajustar líneas ley a tu nivel de mundo'),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Promedio por cada 20 de resina. Por defecto: nivel de mundo 6–8 '
                '(≈ 6 Ingenios del héroe = 120 000 de EXP). Cámbialo si tu mundo es menor.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _numberField(expRate, 'EXP por línea ley', width: 200),
                _numberField(moraRate, 'Mora por línea ley', width: 200),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
        if (planError != null) Text(planError, style: bad),
        const SizedBox(height: 8),
        Text(
          'Catálogo ${widget.bundle.version}. Fuentes comunitarias; las líneas ley son un promedio aproximado.',
          style: theme.textTheme.bodySmall,
        ),
      ],
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
              if (result != null) _results(context, result),
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
