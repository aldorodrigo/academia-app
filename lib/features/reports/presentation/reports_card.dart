import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/reports_repository.dart';

/// Tarjeta del inicio para la comisión: caja y bancos, y morosos.
class ReportsCard extends ConsumerWidget {
  const ReportsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref.watch(currentOrganizationProvider).value?.can('view_reports') ??
        false;
    if (!allowed) return const SizedBox.shrink();

    final today = ref.watch(todayProvider);
    final balanceValue = ref.watch(
      balanceReportProvider(DateTime(today.year, today.month)),
    );
    final delinquentsValue = ref.watch(delinquentsReportProvider);
    final balance = balanceValue.value;
    final delinquents = delinquentsValue.value;
    final loading = balanceValue.isLoading || delinquentsValue.isLoading;

    final details = [
      if (balance != null)
        'Caja y bancos ${formatMoney(balance.closingBalance)}',
      if (delinquents != null) 'Morosos ${formatMoney(delinquents.total)}',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.bar_chart_outlined),
        title: const Text('Informes'),
        subtitle: loading
            ? const LinearProgressIndicator()
            : details.isEmpty
            ? null
            : Text(details),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/informes'),
      ),
    );
  }
}
