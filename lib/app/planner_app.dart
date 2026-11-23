import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_provider.dart';

import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/preferences_controller.dart';
import 'app_router.dart';
import 'app_theme.dart';

class PlannerApp extends ConsumerWidget {
  const PlannerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final mode = switch (preferences.value?.appearance) {
      AppAppearance.dark => ThemeMode.dark,
      AppAppearance.system => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return MaterialApp.router(
      title: 'Genshin Progress Planner',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => preferences.when(
        data: (_) => child!,
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando preferencias',
            ),
          ),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'No pudimos abrir tus preferencias.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Comprueba que puedes acceder al almacenamiento y vuelve a intentarlo. Tus datos no se borrarán.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(databaseProvider);
                      ref.invalidate(preferencesRepositoryProvider);
                      ref.invalidate(preferencesProvider);
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
