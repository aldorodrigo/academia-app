import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/payment_reports_repository.dart';

/// Tarjeta del inicio para quien valida: comprobantes esperando revisión.
class PaymentReportsCard extends ConsumerWidget {
  const PaymentReportsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref
            .watch(currentOrganizationProvider)
            .value
            ?.can('review_payment_reports') ??
        false;
    if (!allowed) return const SizedBox.shrink();

    final reports = ref.watch(paymentReportsProvider(false));
    final pending = reports.value;
    final total = pending?.fold(0, (sum, r) => sum + r.amount) ?? 0;

    return Card(
      child: ListTile(
        leading: Badge(
          isLabelVisible: pending?.isNotEmpty ?? false,
          label: Text('${pending?.length ?? 0}'),
          child: const Icon(Icons.fact_check_outlined),
        ),
        title: const Text('Comprobantes de pago'),
        subtitle: reports.isLoading
            ? const LinearProgressIndicator()
            : pending == null
            ? null
            : Text(
                pending.isEmpty
                    ? 'No hay comprobantes para revisar'
                    : '${pending.length} para revisar · ${formatMoney(total)}',
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/comprobantes'),
      ),
    );
  }
}
