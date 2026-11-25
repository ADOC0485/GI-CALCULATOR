import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../progression/domain/progression_calculator.dart';
import '../data/build_repository.dart';
import '../domain/build.dart';
import 'build_editor_dialog.dart';
import 'build_page.dart' show materialIcon;

/// In the profile settings: builds that reached their goal (kept out of
/// Inicio) and how many builds can be in progress at once.
class FinishedBuildsCard extends ConsumerWidget {
  const FinishedBuildsCard({super.key});

  static String _level(ProgressionState s) =>
      '${s.level}/${ProgressionRules.caps[s.ascension.clamp(0, 6)]}';

  Future<void> _setLimit(BuildContext context, WidgetRef ref, int value) async {
    if (value > BuildRepository.defaultLimit) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Más de 4 builds a la vez?'),
          content: const Text(
            'No es recomendable: los materiales y la resina se reparten entre más '
            'builds y cada una tarda más en terminarse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Dejar 4'),
            ),
            FilledButton(
              key: const ValueKey('limit-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Cambiar a $value'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(buildRepositoryProvider).setActiveLimit(value);
    ref.invalidate(buildLimitProvider);
  }

  Future<void> _newGoal(
    BuildContext context,
    WidgetRef ref,
    CatalogBundle bundle,
    GenshinBuild build,
  ) async {
    final limit = await ref.read(buildLimitProvider.future);
    final active = await ref.read(buildsProvider.future);
    if (!context.mounted) return;
    if (active.length >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BuildLimitException(limit).message)),
      );
      return;
    }
    final created = await showDialog<GenshinBuild>(
      context: context,
      builder: (_) => BuildEditorDialog(bundle: bundle, template: build),
    );
    if (created != null && context.mounted) context.go('/build/${created.id}');
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    GenshinBuild build,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar $name de las terminadas?'),
        content: const Text('Tu inventario y tu historial se conservan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(buildRepositoryProvider).delete(build.id);
    ref.invalidate(finishedBuildsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bundle = ref.watch(catalogProvider).asData?.value;
    final finished = ref.watch(finishedBuildsProvider).asData?.value;
    final limit = ref.watch(buildLimitProvider).asData?.value;
    final byId = {
      for (final r in bundle?.records ?? const <CatalogRecord>[]) r.id: r,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus builds', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Builds en proceso al mismo tiempo:'),
                if (limit != null)
                  DropdownButton<int>(
                    key: const ValueKey('build-limit'),
                    value: limit,
                    items: [
                      for (final v in {
                        ...List.generate(10, (i) => i + 1),
                        limit,
                      })
                        DropdownMenuItem(
                          value: v,
                          child: Text(
                            v == BuildRepository.defaultLimit
                                ? '$v (recomendado)'
                                : '$v',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null && v != limit) _setLimit(context, ref, v);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const ValueKey('finished-builds'),
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle),
              title: Text(
                'Builds terminadas${finished == null ? '' : ' (${finished.length})'}',
              ),
              children: [
                if (finished == null)
                  const LinearProgressIndicator()
                else if (finished.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Cuando subas una build hasta su meta aparecerá aquí, '
                      'y deja de ocupar espacio en Inicio.',
                    ),
                  )
                else
                  for (final b in finished)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: materialIcon(
                        byId[b.characterId ?? b.weaponId]?.image,
                        size: 40,
                      ),
                      title: Text(b.name(byId)),
                      subtitle: Text(
                        [
                          if (b.hasCharacter)
                            'Nivel ${_level(b.characterGoal)}',
                          if (b.talentsUsed)
                            'talentos ${b.characterGoal.talents.join('/')}',
                          if (b.hasWeapon) 'arma ${_level(b.weaponGoal)}',
                          'terminada el ${b.finishedAt!.day}/${b.finishedAt!.month}/${b.finishedAt!.year}',
                        ].join(' · '),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Nueva meta desde aquí',
                            onPressed: bundle == null
                                ? null
                                : () => _newGoal(context, ref, bundle, b),
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            tooltip: 'Borrar',
                            onPressed: () =>
                                _delete(context, ref, b, b.name(byId)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
