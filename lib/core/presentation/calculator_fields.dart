import 'package:flutter/material.dart';

import '../../features/progression/domain/progression_calculator.dart';

int whole(String value, String label) {
  require(
    RegExp(r'^\d+$').hasMatch(value.trim()),
    '$label: introduce un entero no negativo.',
  );
  final result = int.tryParse(value.trim());
  require(
    result != null && result <= 1000000000,
    '$label: cantidad demasiado grande.',
  );
  return result!;
}

class CalculatorField extends StatelessWidget {
  const CalculatorField(
    this.label,
    this.controller,
    this.onChanged, {
    super.key,
    this.width = 230,
    this.lines = 1,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final double width;
  final int lines;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}
