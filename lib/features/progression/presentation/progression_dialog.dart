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

class _ProgressionDialogState extends ConsumerState<ProgressionDialog> {
  final fields = <String, TextEditingController>{
    for (final entry in {
      'Nivel actual': '1',
      'Ascensión actual': '0',
      'EXP parcial actual': '0',
      'Nivel objetivo': '90',
      'Ascensión objetivo': '6',
      'EXP parcial objetivo': '0',
      'Ataque actual': '1',
      'Habilidad actual': '1',
      'Definitiva actual': '1',
      'Ataque objetivo': '1',
      'Habilidad objetivo': '1',
      'Definitiva objetivo': '1',
    }.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  bool busy = false;
  String? notice;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  ProgressionState state(bool target) {
    final suffix = target ? 'objetivo' : 'actual';
    int value(String key) =>
        whole(fields['$key $suffix']!.text, '$key $suffix');
    return ProgressionState(
      level: value('Nivel'),
      ascension: value('Ascensión'),
      experience: value('EXP parcial'),
      talents: [value('Ataque'), value('Habilidad'), value('Definitiva')],
    );
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
          'schema': 1,
          'catalogVersion': widget.bundle.version,
          'fields': fields.map((k, v) => MapEntry(k, v.text)),
        });
        notice = 'Escenario guardado en este equipo.';
      } else {
        final stored = await repo.load(key);
        if (!mounted) return;
        if (stored == null) {
          notice = 'Todavía no hay un escenario guardado.';
        } else {
          final values = stored['fields'] as Map<String, dynamic>;
          for (final entry in fields.entries) {
            if (values[entry.key] is String) {
              entry.value.text = values[entry.key] as String;
            }
          }
          notice = stored['catalogVersion'] == widget.bundle.version
              ? 'Escenario recuperado y recalculado.'
              : 'El catálogo cambió: escenario recalculado con la versión activa.';
        }
      }
    } catch (_) {
      notice = 'No se pudo guardar o recuperar el escenario. Tus datos anteriores se conservan.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
          state(false),
          state(true),
        );
      } on CalculationException catch (e) {
        error = e.message;
      }
    }
    final names = {for (final r in widget.bundle.records) r.id: r.name};
    return AlertDialog(
      title: Text('Calcular · ${widget.record.name}'),
      content: SizedBox(
        width: 850,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hasta nivel 90 · Ascensiones 0–6: límites 20 / 40 / 50 / 60 / 70 / 80 / 90. En un límite puedes elegir antes o después de ascender.',
              ),
              const SizedBox(height: 16),
              for (final target in [false, true]) ...[
                Text(
                  target ? 'Tu objetivo' : 'Tu progreso actual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final label in ['Nivel', 'Ascensión', 'EXP parcial'])
                      CalculatorField(
                        '$label ${target ? 'objetivo' : 'actual'}',
                        fields['$label ${target ? 'objetivo' : 'actual'}']!,
                        () => setState(() => notice = null),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (widget.record.kind == CatalogKind.character) ...[
                const Text(
                  'Talentos base · sin bonos de constelación (por ejemplo, 1 / 10 / 10)',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final target in [false, true])
                      for (final label in ['Ataque', 'Habilidad', 'Definitiva'])
                        CalculatorField(
                          '$label ${target ? 'objetivo' : 'actual'}',
                          fields['$label ${target ? 'objetivo' : 'actual'}']!,
                          () => setState(() => notice = null),
                        ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
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
                const Text(
                  'Plan de libros / minerales: combinación sin bonificaciones, redondeada en cada límite de ascensión. No utiliza armas como alimento.',
                ),
                for (final entry in result.expItems.entries)
                  Text('${entry.key}: ${entry.value}'),
                Text(
                  'EXP suministrada de más: ${result.surplus} (se pierde en límites; puede quedar como EXP parcial al finalizar).',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Materiales totales · ascensión + talentos + Mora de mejora',
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
                  'Catálogo ${widget.bundle.version} · Reglas ${rules!.version}. Fuentes comunitarias revisadas; sin descontar inventario.',
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
