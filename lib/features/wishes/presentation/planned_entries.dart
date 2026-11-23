import 'package:flutter/material.dart';

import '../../../core/presentation/calculator_fields.dart';
import '../../progression/domain/progression_calculator.dart';
import '../domain/wish_calculator.dart';

class PlannedEntries extends StatefulWidget {
  const PlannedEntries({
    required this.controller,
    required this.onChanged,
    required this.day,
    required this.rewards,
    super.key,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  final DateTime day;
  final bool rewards;
  @override
  State<PlannedEntries> createState() => _PlannedEntriesState();
}

class _PlannedEntriesState extends State<PlannedEntries> {
  late final date = TextEditingController(text: dateKey(widget.day));
  final amount = TextEditingController(text: '1');
  bool confirmed = false;
  String? error;
  @override
  void dispose() {
    date.dispose();
    amount.dispose();
    super.dispose();
  }

  void add() {
    try {
      final day = parseDay(date.text.trim());
      final count = whole(amount.text, 'Cantidad');
      require(
        count > 0 && (widget.rewards || count <= 5),
        'Introduce una cantidad positiva${widget.rewards ? '' : ', hasta 5 destinos'}.',
      );
      final row =
          '${dateKey(day)},$count${widget.rewards ? ',${confirmed ? 'confirmado' : 'estimado'}' : ''}';
      widget.controller.text = [
        ...widget.controller.text.split('\n').where((v) => v.isNotEmpty),
        row,
      ].join('\n');
      setState(() => error = null);
      widget.onChanged();
    } on CalculationException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.controller.text
        .split('\n')
        .where((v) => v.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            CalculatorField(
              'Día del juego (AAAA-MM-DD)',
              date,
              () => setState(() => error = null),
            ),
            CalculatorField(
              widget.rewards ? 'Protogemas extra' : 'Destinos a canjear',
              amount,
              () => setState(() => error = null),
            ),
          ],
        ),
        if (widget.rewards)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recompensa confirmada por mí'),
            subtitle: const Text('Sin marcar, se presenta como estimación.'),
            value: confirmed,
            onChanged: (v) => setState(() => confirmed = v!),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: add,
          icon: const Icon(Icons.add),
          label: Text(widget.rewards ? 'Añadir recompensa' : 'Añadir canje'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (var i = 0; i < rows.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(rows[i].split(',').join(' · ')),
            trailing: IconButton(
              tooltip: 'Eliminar entrada',
              icon: const Icon(Icons.close),
              onPressed: () {
                rows.removeAt(i);
                widget.controller.text = rows.join('\n');
                widget.onChanged();
              },
            ),
          ),
        if (rows.isEmpty)
          Text(
            widget.rewards
                ? 'Sin recompensas extra.'
                : 'Sin canjes de polvo previstos.',
          ),
      ],
    );
  }
}
