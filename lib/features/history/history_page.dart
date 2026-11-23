import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/page_frame.dart';
import '../builds/data/build_repository.dart';

/// Log of what changed: new builds, progress updates, inventory and account.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  static String _when(DateTime d) {
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return PageFrame(
      title: 'Historial',
      subtitle: 'Tu avance registrado: builds, progreso, inventario y cuenta.',
      children: [
        history.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('No se pudo leer el historial.'),
          data: (items) => items.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no hay nada. Cuando añadas una build, actualices su progreso '
                      'o guardes tu inventario, quedará anotado aquí.',
                    ),
                  ),
                )
              : Card(
                  child: Column(
                    children: [
                      for (final e in items.reversed)
                        ListTile(
                          leading: const Icon(Icons.history_rounded),
                          title: Text(e.text),
                          subtitle: Text(_when(e.at)),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
