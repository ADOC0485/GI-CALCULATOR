import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/presentation/calculator_fields.dart';
import '../../progression/data/scenario_repository.dart';
import '../../progression/domain/progression_calculator.dart';
import '../domain/wish_calculator.dart';
import 'planned_entries.dart';
import '../domain/zoned_deadline.dart';

final calculationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class WishesPage extends ConsumerStatefulWidget {
  const WishesPage({super.key});
  @override
  ConsumerState<WishesPage> createState() => _WishesPageState();
}

class _WishesPageState extends ConsumerState<WishesPage> {
  late DateTime anchor;
  final fields = <String, TextEditingController>{
    for (final entry in {
      'Protogemas': '0',
      'Destinos entrelazados': '0',
      'Encuentros del destino': '0',
      'Días hasta el objetivo': '30',
      'Fecha objetivo (AAAA-MM-DD)': '',
      'Hora (0–23)': '12',
      'Minuto (0–59)': '0',
      'Días restantes de Bendición': '0',
      'Cristales génesis': '0',
      'Brillo estelar disponible': '0',
      'Destinos a canjear con brillo': '0',
      'Polvo estelar disponible': '0',
      'Canjes de polvo ya hechos este mes': '0',
      'Días sin ingresar': '',
      'Días sin encargos': '',
      'Canjes de polvo previstos': '',
      'Extras de protogemas': '',
    }.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  GameServer server = GameServer.america;
  String zone = 'America/Bogota';
  bool byDate = false,
      acquaint = false,
      crystals = false,
      commissions = true,
      welkinClaimed = true,
      commissionsClaimed = true,
      busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    anchor = ref.read(calculationClockProvider)().toUtc();
    fields['Fecha objetivo (AAAA-MM-DD)']!.text = dateKey(
      anchor.add(const Duration(days: 30)),
    );
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void changed() => setState(() => notice = null);
  int number(String label) => whole(fields[label]!.text, label);
  Iterable<String> lines(String label) => fields[label]!.text
      .split('\n')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty);
  Set<String> exclusions(String label) => fields[label]!.text
      .split(RegExp(r'[,\s]+'))
      .where((v) => v.isNotEmpty)
      .map((v) => dateKey(parseDay(v)))
      .toSet();
  DateTime deadline() {
    if (!byDate) {
      final days = number('Días hasta el objetivo');
      require(days <= 3660, 'El horizonte máximo es de 3660 días.');
      return anchor.add(Duration(days: days));
    }
    return zonedDeadline(
      fields['Fecha objetivo (AAAA-MM-DD)']!.text.trim(),
      number('Hora (0–23)'),
      number('Minuto (0–59)'),
      zone,
    );
  }

  WishInput input() => WishInput(
    now: anchor,
    target: deadline(),
    server: server,
    primogems: number('Protogemas'),
    intertwined: number('Destinos entrelazados'),
    acquaint: number('Encuentros del destino'),
    useAcquaint: acquaint,
    crystals: number('Cristales génesis'),
    convertCrystals: crystals,
    glitter: number('Brillo estelar disponible'),
    glitterWishes: number('Destinos a canjear con brillo'),
    dust: number('Polvo estelar disponible'),
    dustUsedThisMonth: number('Canjes de polvo ya hechos este mes'),
    welkinDays: number('Días restantes de Bendición'),
    welkinTodayClaimed: welkinClaimed,
    commissions: commissions,
    commissionsTodayClaimed: commissionsClaimed,
    skippedLoginDays: exclusions('Días sin ingresar'),
    skippedCommissionDays: exclusions('Días sin encargos'),
    purchases: lines('Canjes de polvo previstos').map((line) {
      final parts = line.split(',');
      require(parts.length == 2, 'Canjes: una línea AAAA-MM-DD,cantidad.');
      return DustPurchase(parseDay(parts[0].trim()), whole(parts[1], 'Canjes'));
    }).toList(),
    rewards: lines('Extras de protogemas').map((line) {
      final parts = line.split(',');
      require(
        parts.length == 3 &&
            ['confirmado', 'estimado'].contains(parts[2].trim()),
        'Extras: una línea AAAA-MM-DD,protogemas,confirmado o estimado.',
      );
      return WishReward(
        parseDay(parts[0].trim()),
        whole(parts[1], 'Extras'),
        confirmed: parts[2].trim() == 'confirmado',
      );
    }).toList(),
  );
  Future<void> storage(bool save) async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final repository = ref.read(scenarioRepositoryProvider);
      if (save) {
        await repository.save('wishes', {
          'schema': 1,
          'rules': '2026.11.23.1',
          'anchor': anchor.toIso8601String(),
          'server': server.name,
          'zone': zone,
          'flags': [
            byDate,
            acquaint,
            crystals,
            commissions,
            welkinClaimed,
            commissionsClaimed,
          ],
          'fields': fields.map((k, v) => MapEntry(k, v.text)),
        });
        notice = 'Escenario guardado en este equipo.';
      } else {
        final stored = await repository.load('wishes');
        if (!mounted) return;
        if (stored == null) {
          notice = 'Todavía no hay un escenario guardado.';
        } else {
          final restoredAnchor = DateTime.parse(stored['anchor'] as String)
              .toUtc();
          final restoredServer = GameServer.values.byName(
            stored['server'] as String,
          );
          final restoredZone = stored['zone'] as String;
          displayLocation(restoredZone);
          final flags = List<bool>.from(stored['flags'] as List);
          require(flags.length == 6, 'Escenario inválido.');
          final values = Map<String, String>.from(stored['fields'] as Map);
          anchor = restoredAnchor;
          server = restoredServer;
          zone = restoredZone;
          byDate = flags[0];
          acquaint = flags[1];
          crystals = flags[2];
          commissions = flags[3];
          welkinClaimed = flags[4];
          commissionsClaimed = flags[5];
          for (final entry in fields.entries) {
            if (values.containsKey(entry.key)) {
              entry.value.text = values[entry.key]!;
            }
          }
          notice = 'Escenario recuperado con su fecha de inicio original. Revisa los saldos antes de actualizar el inicio.';
        }
      }
    } catch (_) {
      notice = 'No se pudo guardar o recuperar el escenario. Tus datos anteriores se conservan.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(String name, {int lines = 1}) => CalculatorField(
    name,
    fields[name]!,
    changed,
    width: lines > 1 ? 600 : 250,
    lines: lines,
  );
  Widget heading(String value) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Text(value, style: Theme.of(context).textTheme.titleLarge),
  );
  @override
  Widget build(BuildContext context) {
    WishResult? result;
    String? error;
    DateTime? target;
    try {
      final values = input();
      target = values.target;
      result = calculateWishes(values);
    } on CalculationException catch (e) {
      error = e.message;
    }
    final local = displayLocation(zone);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Calculadora de deseos',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Proyecta tus recursos. No garantiza personajes ni calcula probabilidades. Los resultados se actualizan al editar.',
        ),
        heading('Lo que tienes'),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            field('Protogemas'),
            field('Destinos entrelazados'),
            field('Encuentros del destino'),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Destinar protogemas y canjes a Encuentros del destino',
          ),
          subtitle: const Text(
            'Desactivado: Destinos entrelazados. El otro tipo se conserva por separado.',
          ),
          value: acquaint,
          onChanged: (v) => setState(() => acquaint = v),
        ),
        heading('Tu horizonte'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<GameServer>(
                isExpanded: true,
                initialValue: server,
                key: ValueKey(server),
                decoration: const InputDecoration(labelText: 'Servidor'),
                items: [
                  for (final s in GameServer.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => server = v!),
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: zone,
                key: ValueKey(zone),
                decoration: const InputDecoration(
                  labelText: 'Zona horaria de visualización',
                ),
                items: [
                  for (final z in [
                    'America/Bogota',
                    'America/Mexico_City',
                    'America/New_York',
                    'Europe/Madrid',
                    'Asia/Shanghai',
                    'Asia/Tokyo',
                    'UTC',
                  ])
                    DropdownMenuItem(value: z, child: Text(z)),
                ],
                onChanged: (v) => setState(() => zone = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Inicio: ${tz.TZDateTime.from(anchor, local)} · Día del juego: ${dateKey(gameDay(anchor, server))}',
        ),
        TextButton(
          onPressed: () => setState(() {
            anchor = ref.read(calculationClockProvider)().toUtc();
            notice = 'Inicio actualizado. Revisa saldos, días de Bendición y recompensas ya reclamadas.';
          }),
          child: const Text('Actualizar inicio a ahora'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Elegir fecha y hora objetivo'),
          value: byDate,
          onChanged: (v) => setState(() => byDate = v),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: byDate
              ? [
                  field('Fecha objetivo (AAAA-MM-DD)'),
                  field('Hora (0–23)'),
                  field('Minuto (0–59)'),
                ]
              : [field('Días hasta el objetivo')],
        ),
        if (target != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Hasta: ${tz.TZDateTime.from(target, local)}. Reinicio a las 04:00 del servidor (UTC${server.offset >= 0 ? '+' : ''}${server.offset}).',
            ),
          ),
        heading('Lo que vas a reclamar'),
        field('Días restantes de Bendición'),
        const SizedBox(height: 8),
        const Text(
          'La vigencia incluye el día actual del juego, aunque ya lo hayas reclamado. No se renueva automáticamente ni se suman 300 cristales iniciales.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bendición de hoy ya reclamada'),
          value: welkinClaimed,
          onChanged: (v) => setState(() => welkinClaimed = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Completar y reclamar todos los encargos'),
          subtitle: const Text(
            '60 protogemas por día previsto; no es el registro de HoYoLAB.',
          ),
          value: commissions,
          onChanged: (v) => setState(() => commissions = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Encargos de hoy ya reclamados'),
          value: commissionsClaimed,
          onChanged: (v) => setState(() => commissionsClaimed = v),
        ),
        const Text(
          'Se prevé ingresar cada día disponible hasta el objetivo. Para excluir días, escribe fechas del juego AAAA-MM-DD separadas por comas.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            field('Días sin ingresar', lines: 2),
            field('Días sin encargos', lines: 2),
          ],
        ),
        heading('Opciones avanzadas'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Convertir los cristales disponibles a protogemas'),
          value: crystals,
          onChanged: (v) => setState(() => crystals = v),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            field('Cristales génesis'),
            field('Brillo estelar disponible'),
            field('Destinos a canjear con brillo'),
            field('Polvo estelar disponible'),
            field('Canjes de polvo ya hechos este mes'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Canjes para el tipo de destino seleccionado: 5 de brillo o 75 de polvo por destino. Polvo: máximo 5 al mes; usa solo el saldo que tienes. Un canje de hoy se incluye en disponibles ahora.',
        ),
        const SizedBox(height: 12),
        PlannedEntries(
          controller: fields['Canjes de polvo previstos']!,
          onChanged: changed,
          day: gameDay(anchor, server),
          rewards: false,
        ),
        const SizedBox(height: 12),
        const Text(
          'Añade recompensas que todavía no estén incluidas en tus saldos. Las fechas son días del juego; para el último día cuenta solo lo que recibirás antes de la hora objetivo.',
        ),
        const SizedBox(height: 12),
        PlannedEntries(
          controller: fields['Extras de protogemas']!,
          onChanged: changed,
          day: gameDay(anchor, server),
          rewards: true,
        ),
        heading('Tu proyección'),
        if (error != null)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (result != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.projected} deseos previstos',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${result.nowWishes} disponibles ahora con las conversiones elegidas · ${result.remainder} protogemas sobrantes',
                  ),
                  Text(
                    'Con extras estimados: ${result.withEstimates} deseos · ${result.estimatedRemainder} protogemas sobrantes',
                  ),
                  Text(
                    'Tipo: ${acquaint ? 'Encuentros del destino' : 'Destinos entrelazados'}. Otros destinos conservados: ${result.otherFates}.',
                  ),
                  const SizedBox(height: 12),
                  for (final entry in result.breakdown.entries)
                    Text('${entry.key}: ${entry.value} protogemas'),
                  Text(
                    'Días con Bendición: ${result.welkinClaims} · Días de encargos: ${result.commissionClaims}',
                  ),
                  Text(
                    'Polvo restante: ${result.remainingDust} · Brillo restante: ${result.remainingGlitter}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Proyección condicionada a tus ingresos y canjes previstos. No supone recompensas de eventos, compras, ni polvo o brillo procedente de futuras tiradas. Reglas 2026.11.23.1.',
                  ),
                ],
              ),
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(notice!),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: busy || result == null ? null : () => storage(true),
              child: const Text('Guardar escenario'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => storage(false),
              child: const Text('Recuperar escenario'),
            ),
          ],
        ),
      ],
    );
  }
}
