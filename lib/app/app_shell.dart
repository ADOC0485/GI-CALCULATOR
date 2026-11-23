import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/progression/data/scenario_repository.dart';
import '../features/profiles/profile.dart';
import '../features/resin/resin_bar.dart';
import 'navigation.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Loads the profiles; switching one rebuilds the pages with its data.
    ref.watch(profilesProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final server = ref.watch(activeServerProvider);
    final selected = AppSection.values.indexWhere((s) => s.path == location);
    final index = selected < 0 ? 0 : selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final rail = constraints.maxWidth >= 680;
        return Scaffold(
          appBar: rail
              ? null
              : AppBar(title: Text(AppSection.values[index].label)),
          drawer: rail
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: _Brand(),
                        ),
                        for (final section in AppSection.values)
                          ListTile(
                            leading: Icon(section.icon),
                            title: Text(section.label),
                            selected: section.index == index,
                            onTap: () {
                              Navigator.pop(context);
                              context.go(section.path);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (rail) ...[
                  ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: SizedBox(
                      width: wide ? 232 : 88,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 30,
                              horizontal: 16,
                            ),
                            child: wide
                                ? const _Brand()
                                : const AppLogo(size: 40),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: IntrinsicHeight(
                                child: NavigationRail(
                                  extended: wide,
                                  minExtendedWidth: 232,
                                  minWidth: 88,
                                  selectedIndex: index,
                                  onDestinationSelected: (value) =>
                                      context.go(AppSection.values[value].path),
                                  destinations: [
                                    for (final section in AppSection.values)
                                      NavigationRailDestination(
                                        icon: Icon(section.icon),
                                        label: Text(section.label),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (wide)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'TU AVENTURA, A TU RITMO',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      letterSpacing: 1.8,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: Column(
                    key: ValueKey('profile-$profileId-$server'),
                    children: [
                      const ResinBar(),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The app icon (moon, calculator and star).
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 40, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/logo.png',
    width: size,
    height: size,
    semanticLabel: 'Genshin Progress Planner',
  );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const AppLogo(size: 40),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'GENSHIN\nPROGRESS PLANNER',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(letterSpacing: 1.6, height: 1.7),
        ),
      ),
    ],
  );
}
