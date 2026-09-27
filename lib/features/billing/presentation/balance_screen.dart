import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/account_repository.dart';
import '../data/models.dart';
import 'charge_tile.dart';
import 'payment_tile.dart';

/// Estado de cuenta de la familia: saldo total, saldo por hijo y cargos.
class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  _Filter _filter = _Filter.unpaid;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de cuenta'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (account) => RefreshIndicator(
          onRefresh: () => ref.refresh(accountProvider.future),
          child: _content(context, account),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final charges = _filter == _Filter.unpaid
        ? account.unpaid
        : account.charges;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Total a pagar', style: theme.textTheme.labelLarge),
        Text(
          formatMoney(account.balance),
          style: theme.textTheme.headlineMedium,
        ),
        if (account.overdue > 0)
          Text(
            'Vencido ${formatMoney(account.overdue)}',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (account.credit > 0)
          Text(
            'Saldo a favor ${formatMoney(account.credit)}',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        if (account.students.length > 1) ...[
          const SizedBox(height: 16),
          for (final student in account.students)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(student.fullName),
              subtitle: student.overdue > 0
                  ? Text(
                      'Vencido ${formatMoney(student.overdue)}',
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  : null,
              trailing: Text(formatMoney(student.balance)),
              onTap: () => context.go('/hijos/${student.id}'),
            ),
        ],
        const SizedBox(height: 16),
        SegmentedButton<_Filter>(
          segments: const [
            ButtonSegment(value: _Filter.unpaid, label: Text('Pendientes')),
            ButtonSegment(value: _Filter.all, label: Text('Todos')),
            ButtonSegment(value: _Filter.payments, label: Text('Pagos')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) => setState(() => _filter = value.first),
        ),
        const SizedBox(height: 8),
        if (_filter == _Filter.payments) ...[
          if (account.payments.isEmpty)
            const _Empty('Todavía no hay pagos registrados.'),
          for (final payment in account.payments) PaymentTile(payment),
        ] else ...[
          if (charges.isEmpty)
            _Empty(
              _filter == _Filter.unpaid
                  ? 'No tenés cargos pendientes.'
                  : 'Todavía no hay cargos.',
            ),
          for (final charge in charges)
            ChargeTile(charge, showStudent: account.students.length > 1),
        ],
      ],
    );
  }
}

enum _Filter { unpaid, all, payments }

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(text, textAlign: TextAlign.center),
  );
}
