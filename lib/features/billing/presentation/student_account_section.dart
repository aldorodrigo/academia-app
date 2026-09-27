import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/account_repository.dart';
import 'charge_tile.dart';

/// Sección "Estado de cuenta" de la ficha del hijo: saldo y cargos impagos.
class StudentAccountSection extends ConsumerWidget {
  const StudentAccountSection({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(studentAccountProvider(studentId));
    final theme = Theme.of(context);

    return account.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(apiErrorMessage(error)),
      data: (account) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            account.dueNow > 0
                ? 'A pagar ahora ${formatMoney(account.dueNow)}'
                : 'Está al día.',
            style: theme.textTheme.titleSmall,
          ),
          if (account.overdue > 0)
            Text(
              'Vencido ${formatMoney(account.overdue)}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (account.upcoming > 0)
            Text('Próximas cuotas ${formatMoney(account.upcoming)}'),
          const SizedBox(height: 8),
          for (final charge in account.dueCharges)
            ChargeTile(charge, showStudent: false),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/estado-de-cuenta'),
              child: const Text('Ver todo'),
            ),
          ),
        ],
      ),
    );
  }
}
