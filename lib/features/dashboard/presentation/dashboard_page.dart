import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/page_frame.dart';
import '../../settings/presentation/theme_toggle_button.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageFrame(
      title: 'Tu próxima aventura',
      subtitle: 'Un lugar para organizar cada paso de tu progreso.',
      action: const ThemeToggleButton(),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'EL VIAJE EMPIEZA AQUÍ',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Cada gran objetivo\ncomienza con un plan.',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Explora personajes, armas y materiales del catálogo inicial.\nConsulta sus fuentes y los datos pendientes de verificación.',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => context.go('/characters'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Explorar catálogo'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              const _OverviewCard(
                icon: Icons.flag_outlined,
                title: 'Tus objetivos',
                message: 'Aún no hay proyectos de progresión.',
              ),
              const _OverviewCard(
                icon: Icons.calendar_today_outlined,
                title: 'Tu agenda',
                message: 'La planificación de actividades estará disponible más adelante.',
              ),
            ];
            if (constraints.maxWidth < 650) {
              return Column(
                children: [cards[0], const SizedBox(height: 16), cards[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 20),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Calculadoras disponibles: personajes, armas, talentos y deseos. Inventario y planificación siguen en preparación.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
      ),
    ),
  );
}
