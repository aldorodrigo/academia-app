import 'package:flutter/material.dart';

import 'vocabulary.dart';

/// Género opcional de una persona: Femenino / Masculino / Sin especificar. Solo sirve para nombrarla bien
/// ("Técnica", "Jugadora"); no se pide en ningún lado como obligatorio.
class GenderChoice extends StatelessWidget {
  const GenderChoice({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Género (opcional)',
  });

  final Gender? value;
  final ValueChanged<Gender?> onChanged;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          for (final (gender, label) in [
            (Gender.female, Gender.female.label),
            (Gender.male, Gender.male.label),
            (null, 'Sin especificar'),
          ])
            ChoiceChip(
              key: Key('gender-${gender?.value ?? 'none'}'),
              label: Text(label),
              selected: value == gender,
              onSelected: (_) => onChanged(gender),
            ),
        ],
      ),
    ],
  );
}
