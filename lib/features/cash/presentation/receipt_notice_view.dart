import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/launcher.dart';
import '../data/models.dart';

/// Después de cobrar: a quién le llega el recibo y por dónde, de verdad ("A
/// Laura Benítez le llega en la app." / "Carlos Ortiz no tiene la app: no le
/// llega."), y "Mandar recibo por WhatsApp a …" para quien no tiene la app y
/// tiene celular (el mensaje lleva el link al recibo, que vale 30 días).
class ReceiptNoticeView extends ConsumerWidget {
  const ReceiptNoticeView(this.notice, {super.key});

  final ReceiptNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notice.reach.isEmpty)
          const Text(
            'La familia no tiene a nadie cargado para avisarle: mandale el '
            'recibo por otro medio.',
          ),
        for (final person in notice.reach)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(person.description, style: theme.textTheme.bodyMedium),
          ),
        for (final person in notice.viaWhatsApp)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_outlined),
              label: Text('Mandar recibo por WhatsApp a ${person.name}'),
              onPressed: () => ref.read(urlLauncherProvider)(
                person.whatsappUri(notice.message),
              ),
            ),
          ),
      ],
    );
  }
}
