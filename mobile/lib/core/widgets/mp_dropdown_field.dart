import 'package:flutter/material.dart';

/// Shared dropdown input that inherits the app's [InputDecorationTheme],
/// matching the visual treatment of [MpTextField].
class MpDropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const MpDropdownField({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      dropdownColor: cs.surfaceContainerHighest,
      style: Theme.of(context).textTheme.titleMedium,
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
