import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_preferences.dart';
import 'preferences_controller.dart';

/// Switches between light and dark mode with one tap.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.filledTonal(
      key: const ValueKey('theme-toggle'),
      tooltip: dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () async {
        try {
          await ref
              .read(preferencesProvider.notifier)
              .setAppearance(dark ? AppAppearance.light : AppAppearance.dark);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo guardar. Se mantiene la apariencia anterior.',
                ),
              ),
            );
          }
        }
      },
    );
  }
}
