import 'package:flutter/material.dart';

enum AppSection {
  dashboard('/dashboard', 'Inicio', Icons.space_dashboard_outlined),
  characters('/characters', 'Personajes', Icons.person_outline_rounded),
  weapons('/weapons', 'Armas', Icons.auto_fix_high_outlined),
  wishes('/wishes', 'Deseos', Icons.auto_awesome_outlined),
  inventory('/inventory', 'Inventario', Icons.inventory_2_outlined),
  agenda('/agenda', 'Agenda', Icons.calendar_month_outlined),
  history('/history', 'Historial', Icons.history_rounded),
  settings('/settings', 'Ajustes', Icons.tune_rounded);

  const AppSection(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}
