import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog.dart';
import 'catalog_provider.dart';
import '../../progression/presentation/progression_dialog.dart';

String kindLabel(CatalogKind kind) => switch (kind) {
  CatalogKind.character => 'Personajes',
  CatalogKind.weapon => 'Armas',
  CatalogKind.material => 'Materiales',
  CatalogKind.activity => 'Actividades',
};
String _searchable(String text) {
  var result = text.toLowerCase();
  for (final pair in ['áa', 'ée', 'íi', 'óo', 'úu', 'üu']) {
    result = result.replaceAll(pair[0], pair[1]);
  }
  return result;
}

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({required this.initialKind, super.key});
  final CatalogKind initialKind;
  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  late CatalogKind _kind = widget.initialKind;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(catalogProvider);
    return value.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Abriendo catálogo'),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se pudo abrir el catálogo. Tus preferencias se conservan.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(catalogProvider);
                },
                child: const Text('Reintentar catálogo'),
              ),
            ],
          ),
        ),
      ),
      data: (bundle) {
        final records =
            bundle.records
                .where(
                  (r) =>
                      r.kind == _kind &&
                      _searchable('${r.name} ${r.id}')
                          .contains(_searchable(_query)),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              kindLabel(_kind),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Catálogo inicial · Genshin ${bundle.gameVersion} · ${bundle.records.length} registros',
            ),
            const SizedBox(height: 12),
            const Text(
              'Datos revisados en fuente comunitaria. Los campos pendientes no se usarán en cálculos exactos.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in CatalogKind.values)
                  ChoiceChip(
                    label: Text(kindLabel(kind)),
                    selected: kind == _kind,
                    onSelected: (_) => setState(() {
                      _kind = kind;
                    }),
                  ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const CatalogImportDialog(),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importar catálogo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Text('${records.length} resultados · Versión ${bundle.version}'),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay coincidencias. Prueba con otro nombre.'),
              ),
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(record.name),
                    subtitle: Text(
                      [
                        if (record.rarity != null) '${record.rarity} ★',
                        if (record.progression?.element != null)
                          record.progression!.element!,
                        if (record.progression?.weaponType != null)
                          record.progression!.weaponType,
                        if (record.material != null) record.material!.category,
                        record.provenance.reliability == Reliability.verified
                            ? (record.pendingFields.isEmpty
                                  ? 'Fuente revisada'
                                  : 'Datos parciales')
                            : 'Pendiente de verificación',
                      ].join(' · '),
                    ),
                    trailing: record.progression == null
                        ? const Icon(Icons.chevron_right)
                        : TextButton.icon(
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('Calcular'),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => ProgressionDialog(
                                bundle: bundle,
                                record: record,
                              ),
                            ),
                          ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _RecordDialog(record: record, bundle: bundle),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecordDialog extends StatelessWidget {
  const _RecordDialog({required this.record, required this.bundle});
  final CatalogRecord record;
  final CatalogBundle bundle;
  @override
  Widget build(BuildContext context) {
    final names = {for (final item in bundle.records) item.id: item.name};
    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final activity = record.activity;
    return AlertDialog(
      title: Text(record.name),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(record.id),
              const SizedBox(height: 12),
              if (record.progression?.region != null)
                Text('Región: ${record.progression!.region}'),
              if (record.pendingFields.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Pendiente: ${record.pendingFields.map(_fieldLabel).join(', ')}.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              for (final requirement
                  in record.progression?.requirements ?? <Requirement>[])
                ExpansionTile(
                  title: Text(
                    requirement.kind == 'ascension'
                        ? 'Ascensión ${requirement.stage}'
                        : 'Talento base ${requirement.stage - 1} → ${requirement.stage}',
                  ),
                  children: [
                    for (final entry in requirement.materials.entries)
                      ListTile(
                        dense: true,
                        title: Text(names[entry.key]!),
                        trailing: Text('${entry.value}'),
                      ),
                  ],
                ),
              if (activity != null) ...[
                Text(
                  'Disponibilidad: ${activity.days.isEmpty ? 'Pendiente' : activity.days.map((d) => dayNames[d - 1]).join(', ')}',
                ),
                Text(
                  'Coste de resina: ${activity.resinCost?.toString() ?? 'Pendiente de verificar'}',
                ),
                if (activity.unlockRank != null)
                  Text('Rango de aventura: ${activity.unlockRank}'),
                const SizedBox(height: 12),
                const Text(
                  'Recompensas posibles (sin cantidades garantizadas):',
                ),
                for (final id in activity.rewards) Text('• ${names[id]}'),
              ],
              if (record.material != null) ...[
                const Text('Fuentes indicadas por el catálogo:'),
                for (final hint in record.material!.sourceHints)
                  Text('• $hint'),
              ],
              if (record.activityIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Actividades relacionadas:'),
                for (final id in record.activityIds) Text('• ${names[id]}'),
              ],
              const Divider(height: 32),
              Text(
                'Fuente revisada: ${record.provenance.verifiedAt} · Juego ${record.provenance.gameVersion}',
              ),
              Text(
                'Estado declarado: ${record.provenance.reliability.name} · Licencia ${record.provenance.license}',
              ),
              Text(record.provenance.method),
              const SizedBox(height: 8),
              SelectableText(record.provenance.source),
              for (final url in record.additionalSources) SelectableText(url),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

String _fieldLabel(String field) => switch (field) {
  'rarity' => 'rareza no documentada',
  'experience' => 'experiencia por nivel y Mora de mejora',
  'levelCaps' => 'límites por ascensión',
  'constellationBonuses' => 'bonificaciones de constelación',
  'resinCost' => 'coste de resina',
  'rewardDistribution' => 'distribución de recompensas',
  'days' => 'calendario',
  'weeklyLimit' => 'límites semanales',
  _ => field,
};

class CatalogImportDialog extends ConsumerStatefulWidget {
  const CatalogImportDialog({super.key});
  @override
  ConsumerState<CatalogImportDialog> createState() =>
      _CatalogImportDialogState();
}

class _CatalogImportDialogState extends ConsumerState<CatalogImportDialog> {
  final _text = TextEditingController();
  CatalogBundle? _preview;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Actualizar catálogo'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega el JSON del catálogo. La validación comprueba estructura y referencias; revisa la procedencia antes de activarlo. No modifica tus preferencias.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'JSON del catálogo',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {
                _preview = null;
                _error = null;
              }),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Versión ${_preview!.version} · ${_preview!.records.length} registros\nSe conservarán las versiones anteriores.',
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () {
                try {
                  final bundle = CatalogBundle.parse(_text.text);
                  setState(() {
                    _preview = bundle;
                    _error = null;
                  });
                } on CatalogValidationException catch (e) {
                  setState(() {
                    _preview = null;
                    _error = e.message;
                  });
                }
              },
        child: const Text('Validar'),
      ),
      FilledButton(
        onPressed: _busy || _preview == null
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await ref
                      .read(catalogRepositoryProvider)
                      .importCatalog(_preview!);
                  if (!mounted || !context.mounted) return;
                  ref.invalidate(catalogProvider);
                  Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _error = e is CatalogValidationException ? e.message : 'No se pudo guardar. El catálogo anterior se conserva.';
                      _busy = false;
                    });
                  }
                }
              },
        child: const Text('Activar catálogo'),
      ),
    ],
  );
}
