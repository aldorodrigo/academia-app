import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../data/models.dart';

/// Pago con su recibo: fecha, monto, método y a qué cargos se aplicó.
class PaymentTile extends ConsumerWidget {
  const PaymentTile(this.payment, {super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final struck = payment.voided
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final url = payment.receiptUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recibo N° ${payment.receiptNumber}',
                    style: theme.textTheme.titleSmall?.merge(struck),
                  ),
                ),
                Text(
                  formatMoney(payment.amount),
                  style: theme.textTheme.titleSmall?.merge(struck),
                ),
              ],
            ),
            Text(
              '${formatDate(payment.receivedOn)} · ${payment.methodLabel}'
              '${payment.voided ? ' · Anulado' : ''}',
              style: payment.voided
                  ? TextStyle(color: theme.colorScheme.error)
                  : theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final allocation in payment.allocations)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${allocation.studentFirstName} · ${allocation.description}',
                    ),
                  ),
                  Text(formatMoney(allocation.amount)),
                ],
              ),
            if (payment.creditGenerated > 0)
              Row(
                children: [
                  const Expanded(child: Text('Saldo a favor')),
                  Text(formatMoney(payment.creditGenerated)),
                ],
              ),
            if (url != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ver recibo'),
                  onPressed: () =>
                      ref.read(urlLauncherProvider)(Uri.parse(url)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
