import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/account_repository.dart';

/// Tarjeta del inicio: total a pagar de la familia y lo vencido.
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
            account.balance > 0
                ? 'Total a pagar ${formatMoney(account.balance)}'
                : 'Estás al día',
          ),
          subtitle: account.overdue > 0
              ? Text(
                  'Vencido ${formatMoney(account.overdue)}',
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/estado-de-cuenta'),
        ),
      ),
    );
  }
}
