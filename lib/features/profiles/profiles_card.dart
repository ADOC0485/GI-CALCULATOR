import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'profile.dart';
import 'profile_dialog.dart';

String profileDetails(Profile p) => [
  p.server,
  if (p.adventureRank != null) 'AR ${p.adventureRank}',
  'Nivel de mundo ${p.worldLevel}',
].join(' · ');

/// Settings: list of profiles to switch, edit, add or delete.
class ProfilesCard extends ConsumerWidget {
  const ProfilesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(profilesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Perfiles', style: theme.textTheme.titleLarge),
                ),
                FilledButton.icon(
                  key: const ValueKey('profile-add'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ProfileDialog(),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Nuevo perfil'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada perfil es una cuenta con sus propias builds, inventario, resina, '
              'agenda e historial. Su nivel de mundo y AR se usan para las líneas ley.',
            ),
            const SizedBox(height: 16),
            profiles.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('No se pudieron cargar los perfiles.'),
              data: (data) => Column(
                children: [
                  for (final p in data.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ProfileAvatar(profile: p, radius: 22),
                      title: Text(
                        p.id == data.activeId ? '${p.name} (en uso)' : p.name,
                      ),
                      subtitle: Text(profileDetails(p)),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (p.id != data.activeId)
                            TextButton(
                              onPressed: () async {
                                await ref
                                    .read(profilesProvider.notifier)
                                    .activate(p.id);
                                if (context.mounted) context.go('/dashboard');
                              },
                              child: const Text('Usar'),
                            ),
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => ProfileDialog(existing: p),
                            ),
                          ),
                          if (p.id != data.activeId)
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      '¿Eliminar el perfil de ${p.name}?',
                                    ),
                                    content: const Text(
                                      'Se borran sus builds, inventario, resina, agenda e '
                                      'historial. No se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(profilesProvider.notifier)
                                      .delete(p.id);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar and name at the top; opens a menu to switch profile.
class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profilesProvider).asData?.value;
    if (data == null) return const SizedBox.shrink();
    final active = data.active;
    return PopupMenuButton<String>(
      key: const ValueKey('profile-switcher'),
      tooltip: 'Cambiar de perfil',
      onSelected: (value) async {
        if (value == '_manage') {
          context.go('/settings');
        } else {
          await ref.read(profilesProvider.notifier).activate(value);
        }
      },
      itemBuilder: (context) => [
        for (final p in data.items)
          PopupMenuItem(
            value: p.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProfileAvatar(profile: p, radius: 16),
              title: Text(p.name),
              subtitle: Text(p.server),
              trailing: p.id == data.activeId ? const Icon(Icons.check) : null,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '_manage',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.manage_accounts_outlined),
            title: Text('Gestionar perfiles'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(profile: active, radius: 16),
            const SizedBox(width: 8),
            Text(active.name, style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
