import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../payment_reports/presentation/payment_report_tile.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Informar transferencia'),
        onPressed: () => context.go('/estado-de-cuenta/informar-pago'),
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
        ? account.dueCharges
        : account.charges;
    final upcoming = account.upcomingCharges;

    return ListView(
      // Abajo, lugar para el botón "Informar transferencia".
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Text('A pagar ahora', style: theme.textTheme.labelLarge),
        Text(
          formatMoney(account.dueNow),
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
        if (account.upcoming > 0)
          Text('Próximas cuotas ${formatMoney(account.upcoming)}'),
        if (account.pendingReportsAmount > 0)
          Text('En revisión ${formatMoney(account.pendingReportsAmount)}'),
        if (account.openReports.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Comprobantes informados', style: theme.textTheme.titleSmall),
          for (final report in account.openReports) PaymentReportTile(report),
        ],
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
              trailing: Text(formatMoney(student.dueNow)),
              onTap: () => context.go('/hijos/${student.id}'),
            ),
        ],
        const SizedBox(height: 16),
        SegmentedButton<_Filter>(
          segments: const [
            ButtonSegment(value: _Filter.unpaid, label: Text('A pagar')),
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
                  ? 'No tenés nada para pagar ahora.'
                  : 'Todavía no hay cargos.',
            ),
          for (final charge in charges)
            ChargeTile(charge, showStudent: account.students.length > 1),
          if (_filter == _Filter.unpaid && upcoming.isNotEmpty)
            _UpcomingCharges(
              upcoming,
              total: account.upcoming,
              showStudent: account.students.length > 1,
            ),
        ],
      ],
    );
  }
}

enum _Filter { unpaid, all, payments }

/// Cuotas creadas por adelantado, plegadas para no confundir con lo que se debe hoy.
class _UpcomingCharges extends StatelessWidget {
  const _UpcomingCharges(
    this.charges, {
    required this.total,
    required this.showStudent,
  });

  final List<Charge> charges;
  final int total;
  final bool showStudent;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const PageStorageKey('upcoming-charges'),
    tilePadding: EdgeInsets.zero,
    title: Text('Próximas cuotas (${charges.length})'),
    subtitle: const Text(
      'Todavía no empezaron; podés pagarlas por adelantado.',
    ),
    trailing: Text(formatMoney(total)),
    children: [
      for (final charge in charges)
        ChargeTile(charge, showStudent: showStudent),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(text, textAlign: TextAlign.center),
  );
}
