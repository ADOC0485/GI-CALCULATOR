import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/domain/catalog.dart';
import '../catalog/presentation/catalog_provider.dart';
import '../progression/domain/inventory_plan.dart';
import '../progression/domain/progression_calculator.dart';
import 'profile.dart';

/// Round picture of the profile's chosen character (or an icon).
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({required this.profile, this.radius = 20, super.key});
  final Profile? profile;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(catalogProvider).asData?.value;
    final image = bundle?.records
        .where((r) => r.id == profile?.avatarId)
        .firstOrNull
        ?.image;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundImage: image == null ? null : NetworkImage(image),
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Icon(Icons.person_outline, size: radius),
    );
  }
}

/// Creates or edits a profile.
class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({this.existing, super.key});
  final Profile? existing;
  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  late final TextEditingController name, world, rank;
  final search = TextEditingController();
  late String server;
  String? gender, avatarId, error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    name = TextEditingController(text: p?.name ?? '');
    world = TextEditingController(text: '${p?.worldLevel ?? 8}');
    rank = TextEditingController(text: p?.adventureRank?.toString() ?? '');
    server = p?.server ?? servers.first;
    gender = p?.gender;
    avatarId = p?.avatarId;
  }

  @override
  void dispose() {
    for (final c in [name, world, rank, search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final trimmed = name.text.trim();
      require(trimmed.isNotEmpty, 'Escribe tu nombre o apodo.');
      require(trimmed.length <= 30, 'El nombre puede tener hasta 30 letras.');
      final wl =
          int.tryParse(world.text.trim()) ??
          (throw const CalculationException(
            'Escribe tu nivel de mundo (0–9).',
          ));
      LeyLineRates.forWorldLevel(wl);
      final ar = int.tryParse(rank.text.trim());
      if (ar != null) LeyLineRates.checkAccount(wl, ar);
      final profile = Profile(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: trimmed,
        server: server,
        worldLevel: wl,
        adventureRank: ar,
        gender: gender,
        avatarId: avatarId,
      );
      await ref
          .read(profilesProvider.notifier)
          .save(profile, activate: widget.existing == null);
      if (mounted) Navigator.pop(context, profile);
    } on CalculationException catch (e) {
      setState(() => error = e.message);
    } on ProfileLimitException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudo guardar el perfil.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _number(TextEditingController c, String label, Key key) => SizedBox(
    width: 180,
    child: TextField(
      key: key,
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundle = ref.watch(catalogProvider).asData?.value;
    final query = search.text.trim().toLowerCase();
    final characters =
        (bundle?.records ?? const <CatalogRecord>[])
            .where(
              (r) =>
                  r.kind == CatalogKind.character &&
                  r.image != null &&
                  (query.isEmpty || r.name.toLowerCase().contains(query)),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo perfil' : 'Editar perfil'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('profile-name'),
                controller: name,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre o apodo',
                  helperText: 'Lo usamos para darte la bienvenida.',
                  border: OutlineInputBorder(),
                ),
              ),
              title('Servidor'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in servers)
                    ChoiceChip(
                      label: Text(s),
                      selected: server == s,
                      onSelected: (_) => setState(() => server = s),
                    ),
                ],
              ),
              title('Tu cuenta'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _number(
                    world,
                    'Nivel de mundo (0–9)',
                    const ValueKey('profile-world'),
                  ),
                  _number(
                    rank,
                    'Rango de aventura (AR)',
                    const ValueKey('profile-rank'),
                  ),
                ],
              ),
              title('Género'),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in ['Femenino', 'Masculino'])
                    ChoiceChip(
                      label: Text(g),
                      selected: gender == g,
                      onSelected: (on) =>
                          setState(() => gender = on ? g : null),
                    ),
                ],
              ),
              title('Avatar'),
              Row(
                children: [
                  ProfileAvatar(
                    profile: Profile(id: '', name: '', avatarId: avatarId),
                    radius: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        labelText: 'Busca tu personaje favorito',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (bundle == null || characters.isEmpty && query.isEmpty)
                const Text(
                  'Actualiza el catálogo desde internet para ver las fotos de los personajes.',
                )
              else
                SizedBox(
                  height: 220,
                  child: GridView.count(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final r in characters)
                        Tooltip(
                          message: r.name,
                          child: InkWell(
                            key: ValueKey('avatar-${r.id}'),
                            borderRadius: BorderRadius.circular(40),
                            onTap: () => setState(() => avatarId = r.id),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 3,
                                  color: avatarId == r.id
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  r.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('profile-save'),
          onPressed: busy ? null : _save,
          child: const Text('Guardar perfil'),
        ),
      ],
    );
  }
}
