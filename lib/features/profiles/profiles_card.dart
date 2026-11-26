import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'profile.dart';
import 'profile_dialog.dart';
import 'transfer_dialogs.dart';

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
    final count = profiles.asData?.value.items.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perfiles${count == null ? '' : ' ($count/${ProfilesController.maxProfiles})'}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('profile-add'),
                  onPressed: () {
                    if ((count ?? 0) >= ProfilesController.maxProfiles) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(const ProfileLimitException().message),
                        ),
                      );
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (_) => const ProfileDialog(),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Nuevo perfil'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-send'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const SendProfileDialog(),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Enviar perfil'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('profile-receive'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const ReceiveProfileDialog(),
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Recibir perfil'),
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
                    _ProfileRow(profile: p, active: p.id == data.activeId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Action { use, edit, delete }

/// One profile in the list. On narrow screens the actions go in a menu so
/// the name and details keep their room.
class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.profile, required this.active});
  final Profile profile;
  final bool active;

  Future<void> _run(BuildContext context, WidgetRef ref, _Action action) async {
    final p = profile;
    switch (action) {
      case _Action.use:
        await ref.read(profilesProvider.notifier).activate(p.id);
        if (context.mounted) context.go('/dashboard');
      case _Action.edit:
        await showDialog<void>(
          context: context,
          builder: (_) => ProfileDialog(existing: p),
        );
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('¿Eliminar el perfil de ${p.name}?'),
            content: const Text(
              'Se borran sus builds, inventario, resina, agenda e '
              'historial. No se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(profilesProvider.notifier).delete(p.id);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final actions = [
      if (!active) _Action.use,
      _Action.edit,
      if (!active) _Action.delete,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final Widget trailing = narrow
            ? PopupMenuButton<_Action>(
                key: ValueKey('profile-menu-${p.id}'),
                tooltip: 'Opciones',
                onSelected: (a) => _run(context, ref, a),
                itemBuilder: (_) => [
                  for (final a in actions)
                    PopupMenuItem(
                      value: a,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(switch (a) {
                          _Action.use => Icons.login,
                          _Action.edit => Icons.edit_outlined,
                          _Action.delete => Icons.delete_outline,
                        }),
                        title: Text(switch (a) {
                          _Action.use => 'Usar',
                          _Action.edit => 'Editar',
                          _Action.delete => 'Eliminar',
                        }),
                      ),
                    ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!active)
                    TextButton(
                      onPressed: () => _run(context, ref, _Action.use),
                      child: const Text('Usar'),
                    ),
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _run(context, ref, _Action.edit),
                  ),
                  if (!active)
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _run(context, ref, _Action.delete),
                    ),
                ],
              );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ProfileAvatar(profile: p, radius: 22),
          title: Text(
            active ? '${p.name} (en uso)' : p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(profileDetails(p)),
          trailing: trailing,
        );
      },
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
            Flexible(
              child: Text(
                active.name,
                style: Theme.of(context).textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
