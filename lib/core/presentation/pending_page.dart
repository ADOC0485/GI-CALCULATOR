import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import 'page_frame.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({required this.section, super.key});
  final AppSection section;
  String get message => switch (section) {
    AppSection.characters => 'Aquí podrás elegir personajes y definir sus objetivos de nivel, ascensión y talentos.',
    AppSection.weapons =>
      'Aquí podrás planificar el nivel y la ascensión de tus armas.',
    AppSection.wishes => 'Proyecta cuántos deseos podrás reunir en una fecha con tus protogemas, destinos, Bendición lunar y encargos.',
    AppSection.inventory => 'Aquí podrás registrar tus materiales y compartirlos entre tus proyectos.',
    AppSection.agenda => 'Aquí verás las actividades recomendadas según tus recursos y disponibilidad.',
    AppSection.history =>
      'Aquí podrás consultar las sesiones de farmeo que registres.',
    _ => '',
  };
  @override
  Widget build(BuildContext context) => PageFrame(
    title: section.label,
    subtitle: message,
    children: [
      Card(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: Column(
              children: [
                Icon(
                  section.icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Este espacio está en preparación',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Disponible en una próxima etapa del planificador.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
