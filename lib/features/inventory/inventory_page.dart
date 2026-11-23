import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/presentation/page_frame.dart';
import '../builds/data/build_repository.dart';
import '../builds/domain/build.dart';
import '../builds/domain/resin_planner.dart';
import '../builds/presentation/build_page.dart';
import '../catalog/domain/catalog.dart';
import '../catalog/presentation/catalog_provider.dart';
import '../progression/domain/inventory_plan.dart';
import '../progression/domain/progression_calculator.dart';
import '../progression/presentation/progression_dialog.dart'
    show progressionRulesProvider;

const _categoryOrder = [
  'Especialidad local',
  'Material de jefe',
  'Gema de ascensión',
  'Botín común',
  'Libro de talento',
  'Material de jefe semanal',
  'Material de ascensión de arma',
];

/// Everything the player owns, shared by the calculator and every build.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final owned = <String, TextEditingController>{};
  final books = List.generate(3, (_) => TextEditingController());
  final ores = List.generate(3, (_) => TextEditingController());
  final mora = TextEditingController();
  final search = TextEditingController();
  final added = <String>{};
  bool loaded = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    ref.read(buildRepositoryProvider).inventory().then((inv) {
      if (!mounted) return;
      setState(() {
        inv.materials.forEach((id, v) => _owned(id).text = '$v');
        for (var i = 0; i < 3; i++) {
          books[i].text = inv.characterBooks[i] == 0 ? '' : '${inv.characterBooks[i]}';
          ores[i].text = inv.weaponOres[i] == 0 ? '' : '${inv.weaponOres[i]}';
        }
        mora.text = inv.mora == 0 ? '' : '${inv.mora}';
        loaded = true;
      });
    });
  }

  TextEditingController _owned(String id) =>
      owned.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final c in [mora, search, ...books, ...ores, ...owned.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final repo = ref.read(buildRepositoryProvider);
      await repo.updateInventory({
        'materials': {for (final e in owned.entries) e.key: e.value.text.trim()},
        'booksCharacter': [for (final b in books) b.text.trim()],
        'booksWeapon': [for (final o in ores) o.text.trim()],
        'mora': mora.text.trim(),
      });
      await repo.log('Inventario actualizado.');
      ref.invalidate(inventoryProvider);
      ref.invalidate(historyProvider);
      setState(() => notice = 'Inventario guardado.');
    } catch (_) {
      setState(() => notice = 'No se pudo guardar el inventario.');
    }
  }

  Widget _field(TextEditingController c, String label, {double width = 110}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            hintText: '0',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => notice = null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundle = ref.watch(catalogProvider).asData?.value;
    final rules = ref.watch(progressionRulesProvider).asData?.value;
    final builds = ref.watch(buildsProvider).asData?.value;
    final inventory = ref.watch(inventoryProvider).asData?.value;
    if (bundle == null || rules == null || builds == null || inventory == null || !loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final byId = {for (final r in bundle.records) r.id: r};

    // Total each material is needed by all builds (before what you own).
    final needed = <String, int>{};
    for (final build in builds) {
      try {
        for (final p in buildNeeds(
          bundle: bundle,
          rules: rules,
          build: build,
          inventory: const Inventory(),
        )) {
          for (final line in p.plan.lines) {
            needed.update(line.id, (v) => v + line.needed, ifAbsent: () => line.needed);
          }
        }
      } on CalculationException {
        // A broken build is shown on its own page; skip it here.
      }
    }
    final ids = {
      ...needed.keys,
      ...owned.entries.where((e) => e.value.text.trim().isNotEmpty).map((e) => e.key),
      ...added,
    }.where((id) => byId[id]?.material != null && id != 'material:202').toList();
    int rank(String id) {
      final i = _categoryOrder.indexOf(byId[id]!.material!.category);
      return i < 0 ? _categoryOrder.length : i;
    }

    ids.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : byId[a]!.name.compareTo(byId[b]!.name);
    });
    final groups = <String, List<String>>{};
    for (final id in ids) {
      groups.putIfAbsent(byId[id]!.material!.category, () => []).add(id);
    }
    final query = search.text.trim().toLowerCase();
    final matches = query.length < 2
        ? <CatalogRecord>[]
        : bundle.records
              .where(
                (r) =>
                    r.material != null &&
                    !ids.contains(r.id) &&
                    r.name.toLowerCase().contains(query),
              )
              .take(8)
              .toList();

    Widget row(String id) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          materialIcon(byId[id]?.image),
          SizedBox(width: 230, child: Text(byId[id]?.name ?? id)),
          _field(_owned(id), 'Tienes'),
          if (needed[id] != null)
            Text(
              'Tus builds piden ${formatNumber(needed[id]!)}',
              style: (int.tryParse(_owned(id).text) ?? 0) >= needed[id]!
                  ? TextStyle(color: theme.colorScheme.primary)
                  : null,
            ),
        ],
      ),
    );

    return PageFrame(
      title: 'Inventario',
      subtitle: 'Lo que tienes, compartido por la calculadora, tus builds y la agenda.',
      action: FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Guardar'),
      ),
      children: [
        if (notice != null)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(notice!)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EXP y Mora', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final (i, item) in [...characterExpItems, ...weaponExpItems].indexed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          materialIcon(byId[item.id]?.image),
                          const SizedBox(width: 6),
                          _field(i < 3 ? books[i] : ores[i - 3], item.label, width: 220),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        materialIcon(byId['material:202']?.image),
                        const SizedBox(width: 6),
                        _field(mora, 'Mora', width: 220),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Materiales', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  builds.isEmpty
                      ? 'Añade una build en Inicio para ver aquí lo que necesita, o busca un material.'
                      : 'Aparecen los materiales que piden tus builds y los que ya registraste.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    labelText: 'Añadir otro material',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                for (final r in matches)
                  ListTile(
                    dense: true,
                    leading: materialIcon(r.image),
                    title: Text(r.name),
                    subtitle: Text(r.material!.category),
                    trailing: const Icon(Icons.add),
                    onTap: () => setState(() {
                      added.add(r.id);
                      search.clear();
                    }),
                  ),
                const SizedBox(height: 12),
                for (final e in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(e.key, style: theme.textTheme.titleSmall),
                  ),
                  for (final id in e.value) row(id),
                ],
                if (builds.isEmpty)
                  TextButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Ir a Inicio para añadir una build'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
