import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/calculator_fields.dart';
import 'package:go_router/go_router.dart';

import '../../builds/data/build_repository.dart';
import '../../builds/domain/build.dart';
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
  final worldLevel = TextEditingController(text: '8');
  final adventureRank = TextEditingController();

  static const inventoryKey = 'inventario';

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadFromBuild();
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
    'worldLevel': worldLevel.text.trim(),
    'adventureRank': adventureRank.text.trim(),
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
      ('worldLevel', worldLevel),
      ('adventureRank', adventureRank),
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
    for (final c in [
      ...books,
      moraOwned,
      worldLevel,
      adventureRank,
      ...owned.values,
    ]) {
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

  /// Starts from the saved build of this character (or the build that uses
  /// this weapon), so the calculator shows where you really are.
  Future<void> _loadFromBuild() async {
    try {
      final builds = await ref.read(buildRepositoryProvider).loadAll();
      final build = builds
          .where(
            (b) =>
                !b.finished &&
                (isCharacter
                    ? b.characterId == widget.record.id
                    : b.weaponId == widget.record.id),
          )
          .firstOrNull;
      if (!mounted || build == null) return;
      void fill(_Side side, ProgressionState state) {
        side.level.text = '${state.level}';
        side.cap = ProgressionRules.caps[state.ascension.clamp(0, 6)];
        for (var i = 0; i < 3 && i < state.talents.length; i++) {
          side.talents[i].text = '${state.talents[i]}';
        }
      }

      setState(() {
        if (isCharacter) {
          fill(now, build.characterNow);
          fill(goal, build.characterGoal);
          talentsOn = build.talentsOn;
        } else {
          fill(now, build.weaponNow);
          fill(goal, build.weaponGoal);
        }
        notice = 'Valores cargados de tu build.';
      });
    } catch (_) {
      // No builds yet: keep the defaults.
    }
  }

  /// Saves what the calculator shows into a build, so it appears in Inicio,
  /// the agenda and the resin plan. Characters create or update their own
  /// build; weapons go into a build whose character uses that weapon type.
  Future<void> saveToBuild() async {
    setState(() {
      busy = true;
      notice = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    try {
      final repo = ref.read(buildRepositoryProvider);
      final from = state(now, 'actual');
      final to = state(goal, 'objetivo');
      final builds = await repo.loadAll();
      final records = {for (final r in widget.bundle.records) r.id: r};
      String level(ProgressionState s) =>
          '${s.level}/${ProgressionRules.caps[s.ascension]}';
      GenshinBuild? saved;
      if (isCharacter) {
        final existing = builds
            .where((b) => !b.finished && b.characterId == widget.record.id)
            .firstOrNull;
        saved = (existing ??
                GenshinBuild(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  characterId: widget.record.id,
                  characterNow: from,
                  characterGoal: to,
                ))
            .copyWith(characterNow: from, characterGoal: to, talentsOn: talentsOn);
        await repo.save(saved);
        await repo.log(
          '${existing == null ? 'Nueva build' : 'Build actualizada'} desde la calculadora: '
          '${widget.record.name} (nivel ${level(from)} → ${level(to)}).',
        );
      } else {
        // Weapons get a build of their own, unless a build in progress
        // already levels this weapon (then that one is updated).
        final existing = builds
            .where((b) => !b.finished && b.weaponId == widget.record.id)
            .firstOrNull;
        saved = (existing ??
                GenshinBuild(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  weaponId: widget.record.id,
                ))
            .copyWith(weaponNow: from, weaponGoal: to);
        await repo.save(saved);
        await repo.log(
          '${existing == null ? 'Nueva build' : 'Build actualizada'} desde la calculadora: '
          '${saved.name(records)} (arma ${level(from)} → ${level(to)}).',
        );
      }
      // What you typed as owned also goes to the shared inventory.
      final scenarios = ref.read(scenarioRepositoryProvider);
      final previous = await scenarios.load(inventoryKey) ?? {};
      await scenarios.save(inventoryKey, {...previous, ..._inventory()});
      ref
        ..invalidate(buildsProvider)
        ..invalidate(inventoryProvider)
        ..invalidate(historyProvider);
      if (!mounted) return;
      Navigator.pop(context);
      final id = saved.id;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Build de ${widget.record.name} guardada.'),
          action: router == null
              ? null
              : SnackBarAction(
                  label: 'Ver build',
                  onPressed: () => router.go('/build/$id'),
                ),
        ),
      );
    } on CalculationException catch (e) {
      setState(() => notice = e.message);
    } on BuildLimitException catch (e) {
      setState(() => notice = e.message);
    } catch (_) {
      setState(() => notice = 'No se pudo guardar en tus builds. Inténtalo de nuevo.');
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

  Widget _icon(String? url, {double size = 36}) => SizedBox(
    width: size,
    height: size,
    child: url == null
        ? Icon(Icons.inventory_2_outlined, size: size * 0.7)
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Icon(Icons.inventory_2_outlined, size: size * 0.7),
          ),
  );

  Widget _results(BuildContext context, ProgressionResult result) {
    final theme = Theme.of(context);
    final records = {for (final r in widget.bundle.records) r.id: r};
    final items = isCharacter ? characterExpItems : weaponExpItems;
    final good = TextStyle(color: theme.colorScheme.primary);
    final bad = TextStyle(color: theme.colorScheme.error);
    const resin = LeyLineRates.resinPerRun;

    LeyLineRates? rates;
    String? accountError, accountHint;
    try {
      final world = whole(worldLevel.text, 'Nivel de mundo');
      rates = LeyLineRates.forWorldLevel(world);
      if (adventureRank.text.trim().isNotEmpty) {
        accountHint = LeyLineRates.checkAccount(
          world,
          whole(adventureRank.text, 'Rango de aventura'),
        );
      }
    } on CalculationException catch (e) {
      accountError = e.message;
    }

    final plan = planInventory(
      bundle: widget.bundle,
      record: widget.record,
      result: result,
      ownedBooks: [for (final b in books) _count(b)],
      ownedMaterials: {
        for (final id in result.materials.keys) id: _count(_owned(id)),
      },
      ownedMora: _count(moraOwned),
      rates: rates ?? const LeyLineRates(),
    );
    final runsKnown = rates != null && accountError == null;

    Widget moraRow(String label, int amount, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_n(amount), style: style),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.materials.isEmpty && result.experience == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Tu progreso ya coincide con el objetivo.'),
          ),
        _section(context, 'Tu cuenta', [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _numberField(
                worldLevel,
                'Nivel de mundo (0–9)',
                width: 190,
                key: const ValueKey('world-level'),
              ),
              _numberField(
                adventureRank,
                'Rango de aventura (AR)',
                width: 190,
                key: const ValueKey('adventure-rank'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (accountError != null)
            Text(accountError, style: bad)
          else if (rates != null) ...[
            Text(
              'En tu nivel de mundo, cada línea ley ($resin de resina) da en '
              'promedio ≈ ${_n(rates.experience)} de EXP o ${_n(rates.mora)} de Mora.',
            ),
            if (accountHint != null) Text(accountHint),
          ],
        ]),
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
              spacing: 16,
              runSpacing: 12,
              children: [
                for (var i = 0; i < items.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _icon(records[items[i].id]?.image),
                      const SizedBox(width: 8),
                      _numberField(
                        books[i],
                        items[i].label,
                        width: 230,
                        key: ValueKey('book-$i'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Con lo que tienes: ${_n(plan.expOwned)} de EXP · llegas a nivel ${plan.levelWithOwned}',
            ),
            if (plan.expMissing == 0)
              Text('¡Te alcanza para todo el nivel!', style: good)
            else ...[
              Text('Te faltan ${_n(plan.expMissing)} de EXP:', style: bad),
              for (final e in plan.booksToFarm.entries)
                Text('• ${e.key}: ${_n(e.value)}'),
              if (isCharacter && runsKnown)
                Text(
                  '≈ ${plan.expRuns} líneas ley de EXP (${_n(plan.expRuns * resin)} de resina)',
                  style: theme.textTheme.titleSmall,
                ),
            ],
          ],
        ),
        _section(context, 'Mora', [
          moraRow(
            'Subir hasta nivel ${result.toLevel} (niveles + ascensiones)',
            result.levelingMora + result.ascensionMora,
          ),
          if (talentsOn && isCharacter)
            moraRow('Subir talentos', result.talentMora),
          if (plan.craftingMora > 0)
            moraRow('Convertir materiales (3 → 1)', plan.craftingMora),
          const Divider(),
          moraRow(
            'Total necesario',
            plan.moraTotal,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _numberField(
            moraOwned,
            'Mora que tienes',
            width: 230,
            key: const ValueKey('mora-owned'),
          ),
          const SizedBox(height: 12),
          if (plan.moraMissing == 0)
            Text('¡Te alcanza la Mora!', style: good)
          else ...[
            Text('Te faltan ${_n(plan.moraMissing)} de Mora', style: bad),
            if (runsKnown)
              Text(
                '≈ ${plan.moraRuns} líneas ley de Mora (${_n(plan.moraRuns * resin)} de resina)',
                style: theme.textTheme.titleSmall,
              ),
          ],
        ]),
        _section(context, 'Materiales', [
          const Text(
            'Pon cuántos tienes de cada uno. Si te sobran del nivel inferior, '
            'se usan convirtiendo 3 en 1, como en la alquimia.',
          ),
          const SizedBox(height: 12),
          for (final line in plan.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _icon(records[line.id]?.image),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 200,
                        child: Text(records[line.id]?.name ?? line.id),
                      ),
                    ],
                  ),
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
        _section(context, 'Consejos', [
          const Text(
            '• Recuerda que en la Tetera de la Serenidad puedes conseguir Mora '
            'y libros de EXP sin gastar resina: reclama cada día la moneda del '
            'reino y cámbiala en la tienda de Tubby (se desbloquea al subir el '
            'nivel de confianza). Ahí también hay Resina transitoria. Las '
            'compras tienen límite semanal, así que revísala cada semana.',
          ),
          const Text(
            '• Las líneas ley son un promedio: el reparto exacto de libros varía en cada recompensa.',
          ),
        ]),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          key: const ValueKey('save-to-build'),
          onPressed: busy || result == null ? null : saveToBuild,
          icon: Icon(isCharacter ? Icons.flag_outlined : Icons.add_link),
          label: Text(isCharacter ? 'Guardar como build' : 'Añadir a una build'),
        ),
      ],
    );
  }
}
