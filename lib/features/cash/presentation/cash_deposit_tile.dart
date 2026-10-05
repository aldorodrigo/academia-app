import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../data/models.dart';

/// Depósito de efectivo: monto, dónde, cuándo y su estado.
class CashDepositTile extends StatelessWidget {
  const CashDepositTile(
    this.deposit, {
    super.key,
    this.showHolder = false,
    this.onWithdraw,
    this.onConfirm,
    this.onReject,
  });

  final CashDeposit deposit;

  /// Para quien valida: quién lo depositó.
  final bool showHolder;
  final VoidCallback? onWithdraw;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = switch (deposit.status) {
      CashDepositStatus.pending => scheme.tertiary,
      CashDepositStatus.confirmed => scheme.primary,
      CashDepositStatus.rejected || CashDepositStatus.voided => scheme.error,
    };
    final details = [
      formatDate(deposit.depositedOn),
      if (deposit.account != null) deposit.account!.name,
      if (deposit.reference != null) deposit.reference!,
    ].join(' · ');
    final hasActions =
        onWithdraw != null || onConfirm != null || onReject != null;

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
                    showHolder && deposit.holderName != null
                        ? deposit.holderName!
                        : 'Depósito',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  formatMoney(deposit.amount),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            Text(details, style: theme.textTheme.bodySmall),
            Text(
              deposit.status.label,
              style: theme.textTheme.labelMedium?.copyWith(color: statusColor),
            ),
            if (deposit.rejectionReason != null)
              Text(
                deposit.rejectionReason!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            if (deposit.notes != null)
              Text(deposit.notes!, style: theme.textTheme.bodySmall),
            if (hasActions)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onWithdraw != null)
                      TextButton(
                        onPressed: onWithdraw,
                        child: const Text('Retirar'),
                      ),
                    if (onReject != null)
                      TextButton(
                        onPressed: onReject,
                        child: const Text('Rechazar'),
                      ),
                    if (onConfirm != null)
                      FilledButton(
                        onPressed: onConfirm,
                        child: const Text('Confirmar'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
