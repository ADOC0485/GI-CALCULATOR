import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../builds/data/build_repository.dart';
import '../../progression/domain/inventory_plan.dart';
import '../../progression/domain/progression_calculator.dart';

/// World Level and Adventure Rank used by default everywhere in the app.
class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key});
  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  final worldLevel = TextEditingController();
  final rank = TextEditingController();
  String? message;
  bool error = false, loaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(buildRepositoryProvider).rawInventory().then((raw) {
      if (!mounted) return;
      setState(() {
        worldLevel.text = '${raw['worldLevel'] ?? 8}';
        rank.text = '${raw['adventureRank'] ?? ''}';
        loaded = true;
      });
    });
  }

  @override
  void dispose() {
    worldLevel.dispose();
    rank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final world = int.tryParse(worldLevel.text.trim()) ??
          (throw const CalculationException('Escribe tu nivel de mundo (0–9).'));
      LeyLineRates.forWorldLevel(world);
      String? hint;
      final ar = int.tryParse(rank.text.trim());
      if (ar != null) hint = LeyLineRates.checkAccount(world, ar);
      await ref.read(buildRepositoryProvider).updateInventory({
        'worldLevel': '$world',
        'adventureRank': ar == null ? '' : '$ar',
      });
      ref.invalidate(inventoryProvider);
      await ref.read(buildRepositoryProvider).log(
        'Cuenta: nivel de mundo $world${ar == null ? '' : ', AR $ar'}.',
      );
      ref.invalidate(historyProvider);
      setState(() {
        error = false;
        message = hint ?? 'Guardado. Se usará en la calculadora, tus builds y la agenda.';
      });
    } on CalculationException catch (e) {
      setState(() {
        error = true;
        message = e.message;
      });
    } catch (_) {
      setState(() {
        error = true;
        message = 'No se pudo guardar. Inténtalo de nuevo.';
      });
    }
  }

  Widget _field(TextEditingController c, String label, Key key) => SizedBox(
    width: 200,
    child: TextField(
      key: key,
      controller: c,
      enabled: loaded,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu cuenta', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Tu nivel de mundo y tu rango de aventura se usan por defecto para '
              'calcular las líneas ley en la calculadora, tus builds y la agenda.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _field(worldLevel, 'Nivel de mundo (0–9)', const ValueKey('account-world')),
                _field(rank, 'Rango de aventura (AR)', const ValueKey('account-rank')),
                FilledButton(
                  key: const ValueKey('account-save'),
                  onPressed: loaded ? _save : null,
                  child: const Text('Guardar'),
                ),
              ],
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  message!,
                  style: error ? TextStyle(color: theme.colorScheme.error) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
