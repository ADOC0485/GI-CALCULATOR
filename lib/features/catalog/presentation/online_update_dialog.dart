import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/genshin_api_source.dart';
import '../domain/catalog.dart';
import 'catalog_provider.dart';

final genshinApiSourceProvider = Provider((ref) => GenshinApiSource());

String onlineVersionFor(UpstreamRevision revision) =>
    'genshin-api-${revision.sha.substring(0, 12)}';

/// Checks GitHub for newer genshin-api data and stores it on this device.
class OnlineUpdateDialog extends ConsumerStatefulWidget {
  const OnlineUpdateDialog({super.key});
  @override
  ConsumerState<OnlineUpdateDialog> createState() => _OnlineUpdateDialogState();
}

class _OnlineUpdateDialogState extends ConsumerState<OnlineUpdateDialog> {
  UpstreamRevision? _latest;
  String? _message, _error;
  bool _busy = true, _upToDate = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on CatalogDownloadException catch (e) {
      _error = e.message;
    } on CatalogValidationException catch (e) {
      _error = 'Los datos descargados no pasaron la validación: ${e.message}';
    } catch (_) {
      _error = 'No se pudo actualizar. Tu catálogo actual se conserva.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _run(() async {
    final latest = await ref.read(genshinApiSourceProvider).latestRevision();
    final active = await ref.read(catalogRepositoryProvider).loadActive();
    _latest = latest;
    _upToDate = active?.version == onlineVersionFor(latest);
    _message = _upToDate
        ? 'Ya tienes los datos más recientes de genshin-api.'
        : 'Hay datos del ${_day(latest.committedAt)} disponibles en GitHub.';
  });

  Future<void> _download() => _run(() async {
    final bundle = await ref.read(genshinApiSourceProvider).download(_latest!);
    final result = await ref
        .read(catalogRepositoryProvider)
        .importCatalog(bundle);
    ref.invalidate(catalogProvider);
    _upToDate = true;
    int count(CatalogKind kind) =>
        bundle.records.where((r) => r.kind == kind).length;
    _message = result.changed
        ? 'Catálogo actualizado: ${count(CatalogKind.character)} personajes, '
              '${count(CatalogKind.weapon)} armas y '
              '${count(CatalogKind.material)} materiales.'
        : 'Ya tienes los datos más recientes de genshin-api.';
  });

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Actualizar desde internet'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descarga personajes, armas y materiales de genshin-api en GitHub '
            'y los guarda en este equipo. Después la calculadora funciona sin '
            'internet. Tus escenarios y preferencias no se tocan.',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null && !_busy) Text(_message!),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      if (_latest == null && _error != null)
        FilledButton(
          onPressed: _busy ? null : _check,
          child: const Text('Reintentar'),
        ),
      if (_latest != null && !_upToDate)
        FilledButton(
          onPressed: _busy ? null : _download,
          child: const Text('Descargar y activar'),
        ),
    ],
  );
}
