import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/reports_repository.dart';
import 'report_widgets.dart';

/// Informes para la comisión: balance del mes, saldos por familia y morosos.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final allowed = organization.value?.can('view_reports') ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Informes'),
          leading: BackButton(onPressed: () => context.go('/inicio')),
          bottom: allowed
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Balance'),
                    Tab(text: 'Saldos'),
                    Tab(text: 'Morosos'),
                  ],
                )
              : null,
        ),
        body: organization.isLoading
            ? const Center(child: CircularProgressIndicator())
            : !allowed
            ? const Center(child: Text('No tenés acceso a los informes.'))
            : const TabBarView(
                children: [_BalanceTab(), _BalancesTab(), _DelinquentsTab()],
              ),
      ),
    );
  }
}

class _BalanceTab extends ConsumerStatefulWidget {
  const _BalanceTab();

  @override
  ConsumerState<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends ConsumerState<_BalanceTab> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final month = _month ?? DateTime(today.year, today.month);
    final report = ref.watch(balanceReportProvider(month));
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _month = DateTime(month.year, month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  formatPeriod(
                    '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                  () => _month = DateTime(month.year, month.month + 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReportBody<BalanceReport>(
            value: report,
            onRefresh: () => ref.refresh(balanceReportProvider(month).future),
            builder: (r) => [
              ReportSection(
                'Resumen',
                children: [
                  AmountRow('Saldo inicial', r.openingBalance),
                  AmountRow('Ingresos', r.incomeTotal),
                  AmountRow('Gastos', -r.expensesTotal),
                  if (r.other != 0) AmountRow('Otros movimientos', r.other),
                  const Divider(),
                  AmountRow('Saldo final', r.closingBalance, bold: true),
                  if (r.pendingExpenses > 0)
                    AmountRow(
                      'Gastos pendientes de pago',
                      r.pendingExpenses,
                      color: theme.colorScheme.error,
                    ),
                ],
              ),
              ReportSection(
                'Ingresos',
                children: [
                  if (r.income.isEmpty)
                    const Text('Sin ingresos en el período.'),
                  for (final line in r.income)
                    AmountRow(line.label, line.amount),
                ],
              ),
              ReportSection(
                'Gastos',
                children: [
                  if (r.expenses.isEmpty)
                    const Text('Sin gastos en el período.'),
                  for (final line in r.expenses)
                    AmountRow(line.label, line.amount),
                ],
              ),
              ReportSection(
                'Cuentas',
                children: [
                  for (final account in r.accounts)
                    AmountRow(account.name, account.balance),
                ],
              ),
              const SizedBox(height: 8),
              DownloadButtons(r.links),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalancesTab extends ConsumerWidget {
  const _BalancesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ReportBody<BalancesReport>(
      value: ref.watch(balancesReportProvider),
      onRefresh: () => ref.refresh(balancesReportProvider.future),
      builder: (r) => [
        ReportSection(
          'Totales',
          children: [
            AmountRow('Pendiente de cobro', r.pending, bold: true),
            AmountRow('Vencido', r.overdue, color: theme.colorScheme.error),
            if (r.credit > 0) AmountRow('Saldo a favor', r.credit),
          ],
        ),
        DownloadButtons(r.links),
        const SizedBox(height: 8),
        if (r.families.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todas las familias están al día.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final family in r.families)
          Card(
            child: ListTile(
              title: Text(family.family),
              subtitle: Text(
                [
                  family.students.join(', '),
                  if (family.overdue > 0)
                    'Vencido ${formatMoney(family.overdue)}',
                  if (family.credit > 0)
                    'Saldo a favor ${formatMoney(family.credit)}',
                ].join(' · '),
              ),
              trailing: Text(
                formatMoney(family.pending),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _DelinquentsTab extends ConsumerWidget {
  const _DelinquentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final open = ref.read(urlLauncherProvider);
    return ReportBody<DelinquentsReport>(
      value: ref.watch(delinquentsReportProvider),
      onRefresh: () => ref.refresh(delinquentsReportProvider.future),
      builder: (r) => [
        ReportSection(
          'Total vencido',
          children: [
            AmountRow(
              '${r.families.length} familias',
              r.total,
              bold: true,
              color: theme.colorScheme.error,
            ),
          ],
        ),
        DownloadButtons(r.links),
        const SizedBox(height: 8),
        if (r.families.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay morosos.', textAlign: TextAlign.center),
          ),
        for (final d in r.families)
          Card(
            child: ListTile(
              title: Text(d.family),
              subtitle: Text(
                [
                  d.students.join(', '),
                  '${d.monthsOverdue} ${d.monthsOverdue == 1 ? 'mes' : 'meses'} · desde ${formatDate(d.oldestDueOn)}',
                  if (d.contactName != null) d.contactName!,
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(d.overdue),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (d.contactPhone != null)
                    InkWell(
                      onTap: () => open(
                        Uri(
                          scheme: 'tel',
                          path: d.contactPhone!.replaceAll(' ', ''),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Llamar',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
