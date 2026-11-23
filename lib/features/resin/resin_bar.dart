import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profiles/profiles_card.dart';
import 'resin_state.dart';

String _clock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Resin summary shown at the top of every page, like the in-game counter.
class ResinBar extends ConsumerStatefulWidget {
  const ResinBar({super.key});
  @override
  ConsumerState<ResinBar> createState() => _ResinBarState();
}

class _ResinBarState extends ConsumerState<ResinBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resin = ref.watch(resinProvider).asData?.value;
    if (resin == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ProfileSwitcher(),
        ),
      );
    }
    final now = ref.watch(resinClockProvider)();
    final original = resin.originalAt(now);
    final next = resin.nextIn(now);
    final full = resin.fullIn(now);
    Widget pill(IconData icon, String text, {String? tooltip, Color? color}) =>
        Tooltip(
          message: tooltip ?? text,
          child: Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(icon, size: 18, color: color),
            label: Text(text),
          ),
        );
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const ProfileSwitcher(),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  pill(
                    Icons.nightlight_round,
                    '$original/${ResinState.cap}',
                    tooltip: 'Resina original',
                    color: Colors.lightBlueAccent,
                  ),
                  Text(
                    next == null
                        ? 'Llena'
                        : '+1 en ${_clock(next)} · llena en ${_clock(full!)}',
                    key: const ValueKey('resin-timer'),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (resin.condensed > 0)
                    pill(
                      Icons.hexagon_outlined,
                      '${resin.condensed}',
                      tooltip: 'Resina concentrada (dominios y líneas ley)',
                      color: Colors.amber,
                    ),
                  if (resin.fragile > 0)
                    pill(
                      Icons.water_drop_outlined,
                      '${resin.fragile}',
                      tooltip: 'Resina frágil (+60 cada una)',
                      color: Colors.cyan,
                    ),
                  if (resin.transient > 0)
                    pill(
                      Icons.hourglass_bottom,
                      '${resin.transient}',
                      tooltip:
                          'Resina transitoria (+60, caduca: úsala primero)',
                      color: Colors.purpleAccent,
                    ),
                  Text(
                    'Total ${resin.totalAt(now)}',
                    style: theme.textTheme.labelLarge,
                  ),
                  IconButton(
                    key: const ValueKey('resin-edit'),
                    tooltip: 'Editar resina',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const ResinDialog(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResinDialog extends ConsumerStatefulWidget {
  const ResinDialog({super.key});
  @override
  ConsumerState<ResinDialog> createState() => _ResinDialogState();
}

class _ResinDialogState extends ConsumerState<ResinDialog> {
  late final TextEditingController original, condensed, fragile, transient;
  String? error;

  @override
  void initState() {
    super.initState();
    final now = ref.read(resinClockProvider)();
    final r = ref.read(resinProvider).asData?.value ?? ResinState.initial(now);
    original = TextEditingController(text: '${r.originalAt(now)}');
    condensed = TextEditingController(text: '${r.condensed}');
    fragile = TextEditingController(text: '${r.fragile}');
    transient = TextEditingController(text: '${r.transient}');
  }

  @override
  void dispose() {
    for (final c in [original, condensed, fragile, transient]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    int read(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final o = read(original), c = read(condensed);
    if (o > 2000) {
      setState(() => error = 'La resina original no pasa de 2000.');
      return;
    }
    if (c > ResinState.maxCondensed) {
      setState(
        () => error =
            'Solo puedes tener ${ResinState.maxCondensed} de resina concentrada.',
      );
      return;
    }
    try {
      await ref
          .read(resinProvider.notifier)
          .set(
            original: o,
            condensed: c,
            fragile: read(fragile),
            transient: read(transient),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => error = 'No se pudo guardar. Inténtalo de nuevo.');
    }
  }

  Widget _row(
    TextEditingController c,
    String label,
    String help,
    IconData icon,
    Color color,
    Key key,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 12),
          child: Icon(icon, color: color),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            key: key,
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(help),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tu resina'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ponla como la ves en el juego. La resina original se recarga sola '
              '(1 cada 8 minutos, hasta 200) desde que guardas.',
            ),
            const SizedBox(height: 16),
            _row(
              original,
              'Original',
              'Sirve para todo. Se recarga con el tiempo.',
              Icons.nightlight_round,
              Colors.lightBlueAccent,
              const ValueKey('resin-original'),
            ),
            _row(
              condensed,
              'Concentrada',
              'Máximo 5. Vale 40 y da recompensa doble, '
                  'pero solo en dominios y líneas ley (no en jefes).',
              Icons.hexagon_outlined,
              Colors.amber,
              const ValueKey('resin-condensed'),
            ),
            _row(
              fragile,
              'Frágil',
              'Cada una da 60 de resina original (pase de batalla, eventos).',
              Icons.water_drop_outlined,
              Colors.cyan,
              const ValueKey('resin-fragile'),
            ),
            _row(
              transient,
              'Transitoria',
              'Da 60 de resina original y caduca: gástala primero (Tetera).',
              Icons.hourglass_bottom,
              Colors.purpleAccent,
              const ValueKey('resin-transient'),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('resin-save'),
        onPressed: _save,
        child: const Text('Guardar'),
      ),
    ],
  );
}
