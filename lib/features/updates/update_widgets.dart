import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update.dart';

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
          release.notes.trim().isEmpty ? 'Sin notas para esta versión.' : release.notes,
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
                  onPressed: () =>
                      ref.read(dismissedUpdateProvider.notifier).dismiss(release.version),
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
                          opened ? _howToInstall : 'No se pudo abrir el enlace: $releasesPage',
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

/// Settings: installed version and a button to check for updates.
class AboutCard extends ConsumerWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = ref.watch(latestReleaseProvider);
    final release = latest.asData?.value;
    final newer = release != null && release.isNewerThan(appVersion);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión de la app', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tienes la v$appVersion.', key: const ValueKey('app-version')),
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
                  onPressed: () => ref.invalidate(latestReleaseProvider),
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
          ],
        ),
      ),
    );
  }
}
