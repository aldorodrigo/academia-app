import 'package:flutter/material.dart';

/// "Acepto los términos de uso y la política de datos personales.": obligatorio
/// al crear una cuenta (registro o invitación). Se valida con `validateTerms`.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    onChanged: (v) => onChanged(v ?? false),
    title: const Text(
      'Acepto los términos de uso y la política de datos personales.',
    ),
  );
}
