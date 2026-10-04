import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/account_repository.dart';

/// Tarjeta del inicio: lo que la familia tiene que pagar ahora, lo vencido
/// y las próximas cuotas.
class AccountSummaryCard extends ConsumerWidget {
  const AccountSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final theme = Theme.of(context);

    return account.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(apiErrorMessage(error)),
      data: (account) => Card(
        child: ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(
            account.dueNow > 0
                ? 'A pagar ahora ${formatMoney(account.dueNow)}'
                : 'Estás al día',
          ),
          subtitle: account.overdue > 0
              ? Text(
                  'Vencido ${formatMoney(account.overdue)}',
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : account.pendingReportsAmount > 0
              ? Text('En revisión ${formatMoney(account.pendingReportsAmount)}')
              : account.credit > 0
              ? Text('Saldo a favor ${formatMoney(account.credit)}')
              : account.upcoming > 0
              ? Text('Próximas cuotas ${formatMoney(account.upcoming)}')
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/estado-de-cuenta'),
        ),
      ),
    );
  }
}
