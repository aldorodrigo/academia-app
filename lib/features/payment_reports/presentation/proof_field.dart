import 'package:flutter/material.dart';

import '../data/report_form.dart';

/// Botón para adjuntar el comprobante (foto o PDF) y el archivo elegido.
/// Lo usan el tutor al informar una transferencia y quien cobra al registrar
/// la que le mandó la familia.
class ProofField extends StatelessWidget {
  const ProofField({
    super.key,
    required this.proof,
    required this.error,
    required this.onPick,
    this.hint = 'Captura o PDF de la transferencia, hasta 5 MB.',
  });

  final PickedProof? proof;
  final String? error;
  final VoidCallback? onPick;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = proof;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file == null)
          OutlinedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Adjuntar comprobante'),
            onPressed: onPick,
          )
        else
          Card(
            child: ListTile(
              leading: Icon(
                file.name.toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
              ),
              title: Text(file.name),
              subtitle: Text(_size(file.bytes.length)),
              trailing: TextButton(
                onPressed: onPick,
                child: const Text('Cambiar'),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          )
        else if (file == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(hint, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
