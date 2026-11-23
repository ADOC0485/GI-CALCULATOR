import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/page_frame.dart';
import '../domain/app_preferences.dart';
import '../../profiles/profiles_card.dart';
import 'preferences_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _saving = false;
  Future<void> _setAppearance(AppAppearance appearance) async {
    setState(() => _saving = true);
    try {
      await ref.read(preferencesProvider.notifier).setAppearance(appearance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apariencia guardada en este dispositivo.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Tu preferencia anterior se conserva. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesProvider).requireValue;
    return PageFrame(
      title: 'Ajustes',
      subtitle: 'Haz de este espacio tu compañero de aventuras.',
      children: [
        const ProfilesCard(),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apariencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Elige cómo quieres ver el planificador. Los cambios se guardan automáticamente.',
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final appearance in AppAppearance.values)
                      ChoiceChip(
                        key: ValueKey('appearance-${appearance.name}'),
                        avatar: Icon(switch (appearance) {
                          AppAppearance.dark => Icons.dark_mode_outlined,
                          AppAppearance.light => Icons.light_mode_outlined,
                          AppAppearance.system =>
                            Icons.desktop_windows_outlined,
                        }),
                        label: Text(switch (appearance) {
                          AppAppearance.dark => 'Oscuro',
                          AppAppearance.light => 'Claro',
                          AppAppearance.system => 'Sistema',
                        }),
                        selected: preferences.appearance == appearance,
                        onSelected: _saving
                            ? null
                            : (selected) {
                                if (selected) _setAppearance(appearance);
                              },
                      ),
                  ],
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Guardando apariencia',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'En tu dispositivo, bajo tu control',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tus preferencias se conservan al cerrar la aplicación. No necesitas una cuenta ni conexión a internet.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
