import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update.dart';
import 'code_push.dart';

/// Opens the download: the APK on Android, the release page elsewhere.
Future<bool> openUpdate(AppRelease release) {
  final target = Platform.isAndroid && release.apkUrl != null
      ? release.apkUrl!
      : release.pageUrl;
  return launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
}

void _showNotes(BuildContext context, AppRelease release) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Novedades de la ${release.version}'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Text(
          release.notes.trim().isEmpty
              ? 'Sin notas para esta versión.'
              : release.notes,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  ),
);

/// Shown in Settings and in the README.
const unofficialNotice =
    'Esta es una app hecha por fans. No está afiliada, respaldada ni '
    'patrocinada por HoYoverse ni COGNOSPHERE. Genshin Impact, sus personajes, '
    'imágenes y contenido del juego son marcas y propiedad de HoYoverse / '
    'COGNOSPHERE. La app es gratuita y no usa ni pide tu cuenta del juego. '
    'Si eres titular de derechos y quieres que se retire algún contenido, '
    'abre un issue en el repositorio de GitHub.';

const dataCredits = [
  'Personajes, armas, materiales e imágenes: genshin-api (devesh-anand), '
      'que a su vez usa yatta.moe, Enka.Network y la wiki de Fandom.',
  'Nombres en español y catálogo inicial: genshin-db (theBowja), licencia MIT.',
  'Tablas de EXP: paimon-moe (MadeBaruna), licencia MIT.',
  'Promedios de recompensas y líneas ley: guías y wikis de la comunidad.',
];

const _howToInstall =
    'Se descarga desde GitHub. Ábrelo y toca «Actualizar»: se instala encima '
    'y conservas todos tus datos.';

/// Banner under the top bar when GitHub has a newer version.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(latestReleaseProvider).asData?.value;
    final dismissed = ref.watch(dismissedUpdateProvider);
    if (release == null ||
        !release.isNewerThan(appVersion) ||
        dismissed == release.version) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_outlined),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Hay una versión nueva: ${release.version} (tienes la v$appVersion).',
                    key: const ValueKey('update-banner'),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => ref
                      .read(dismissedUpdateProvider.notifier)
                      .dismiss(release.version),
                  child: const Text('Ahora no'),
                ),
                TextButton(
                  onPressed: () => _showNotes(context, release),
                  child: const Text('Novedades'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final opened = await openUpdate(release);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          opened
                              ? _howToInstall
                              : 'No se pudo abrir el enlace: $releasesPage',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown when a patch (small fix) finished downloading: it is used the
/// next time the app is opened. Shorebird downloads it by itself on launch,
/// so this looks again a little later.
class PatchBanner extends ConsumerStatefulWidget {
  const PatchBanner({
    super.key,
    this.recheckAfter = const Duration(seconds: 45),
  });
  final Duration recheckAfter;
  @override
  ConsumerState<PatchBanner> createState() => _PatchBannerState();
}

class _PatchBannerState extends ConsumerState<PatchBanner> {
  Timer? _recheck;
  bool _hidden = false;

  @override
  void dispose() {
    _recheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patchStateProvider).asData?.value;
    if (state != null &&
        state.available &&
        !state.restartRequired &&
        _recheck == null) {
      _recheck = Timer(widget.recheckAfter, () {
        if (mounted) ref.invalidate(patchStateProvider);
      });
    }
    if (_hidden || state == null || !state.restartRequired) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.auto_fix_high_outlined),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Se descargó una mejora. Cierra y vuelve a abrir la app para usarla.',
                key: ValueKey('patch-banner'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _hidden = true),
              child: const Text('Ok'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings: installed version and a button to check for updates.
class AboutCard extends ConsumerWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = ref.watch(latestReleaseProvider);
    final release = latest.asData?.value;
    final newer = release != null && release.isNewerThan(appVersion);
    final patch = ref.watch(patchStateProvider).asData?.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión de la app', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tienes la v$appVersion'
              '${patch?.current != null ? ' (parche ${patch!.current})' : ''}.',
              key: const ValueKey('app-version'),
            ),
            if (patch?.restartRequired ?? false)
              Text(
                'Hay una mejora descargada: cierra y vuelve a abrir la app para usarla.',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            const SizedBox(height: 8),
            if (latest.isLoading)
              const LinearProgressIndicator()
            else if (newer)
              Text(
                'Hay una versión nueva en GitHub: ${release.version}.',
                style: TextStyle(color: theme.colorScheme.primary),
              )
            else if (release != null)
              const Text('Tienes la última versión publicada.')
            else
              const Text(
                'No se pudo consultar GitHub (sin conexión o aún no hay versiones publicadas).',
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('check-updates'),
                  onPressed: () async {
                    ref.invalidate(latestReleaseProvider);
                    if (!(patch?.available ?? false)) return;
                    final messenger = ScaffoldMessenger.of(context);
                    var downloaded = false;
                    try {
                      downloaded = await ref
                          .read(codePushProvider)
                          .downloadUpdate();
                    } catch (_) {}
                    ref.invalidate(patchStateProvider);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          downloaded
                              ? 'Mejora descargada: cierra y vuelve a abrir la app para usarla.'
                              : 'No hay mejoras nuevas por ahora.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Buscar actualizaciones'),
                ),
                if (newer)
                  FilledButton.icon(
                    onPressed: () => openUpdate(release),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Actualizar'),
                  ),
              ],
            ),
            if (newer)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(_howToInstall),
              ),
            const Divider(height: 40),
            Text('Proyecto no oficial', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(unofficialNotice, key: ValueKey('unofficial-notice')),
            const SizedBox(height: 12),
            Text('Créditos de los datos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final line in dataCredits) Text('• $line'),
          ],
        ),
      ),
    );
  }
}
