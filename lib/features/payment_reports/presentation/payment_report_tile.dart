import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../../billing/data/account_repository.dart';
import '../data/models.dart';
import '../data/payment_reports_repository.dart';
import '../../organizations/data/organization_repository.dart';

/// Comprobante informado por el tutor: en revisión (se puede retirar) o
/// rechazado con el motivo.
class PaymentReportTile extends ConsumerWidget {
  const PaymentReportTile(this.report, {super.key});

  final PaymentReport report;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar el comprobante?'),
        content: Text(
          '${ref.read(orgWordProvider).theUpper()} no lo va a revisar. '
          'Podés informar el pago de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(paymentReportsRepositoryProvider).withdraw(report.id);
      ref.invalidate(accountProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rejected = report.status == PaymentReportStatus.rejected;
    final proof = report.proofUrl;

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
                    'Transferencia del ${formatDate(report.paidOn)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  formatMoney(report.amount),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                rejected ? Icons.error_outline : Icons.hourglass_top,
                size: 18,
                color: rejected ? theme.colorScheme.error : null,
              ),
              label: Text(report.status.label),
            ),
            const SizedBox(height: 4),
            Text(report.chargesSummary),
            if (report.registeredBy != null)
              Text(
                'Registrado por ${report.registeredBy}',
                style: theme.textTheme.bodySmall,
              ),
            if (rejected && report.rejectionReason != null)
              Text(
                'Motivo: ${report.rejectionReason}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (proof != null)
                  TextButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Ver comprobante'),
                    onPressed: () =>
                        ref.read(urlLauncherProvider)(Uri.parse(proof)),
                  ),
                // Lo que registró el club lo retira quien lo registró, no la familia.
                if (report.isPending && report.registeredBy == null)
                  TextButton(
                    onPressed: () => _withdraw(context, ref),
                    child: const Text('Retirar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
