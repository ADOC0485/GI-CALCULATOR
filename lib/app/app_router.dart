import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/pending_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/catalog/domain/catalog.dart';
import '../features/catalog/presentation/catalog_page.dart';
import 'app_shell.dart';
import 'navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          for (final section in AppSection.values)
            GoRoute(
              path: section.path,
              builder: (context, state) => switch (section) {
                AppSection.dashboard => const DashboardPage(),
                AppSection.settings => const SettingsPage(),
                AppSection.characters => const CatalogPage(
                  key: ValueKey('characters'),
                  initialKind: CatalogKind.character,
                ),
                AppSection.weapons => const CatalogPage(
                  key: ValueKey('weapons'),
                  initialKind: CatalogKind.weapon,
                ),
                _ => PendingPage(section: section),
              },
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Página no encontrada · Volver al inicio'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
