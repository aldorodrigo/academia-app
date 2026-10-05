import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/cash_form.dart';
import '../data/cash_repository.dart';
import '../data/models.dart';
import 'cash_deposit_tile.dart';

/// "Efectivo" (quien valida): cuánta plata del club tiene cada uno que cobra en
/// efectivo y los depósitos por confirmar.
class CashOverviewScreen extends ConsumerWidget {
  const CashOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(cashOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Efectivo'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(cashOverviewProvider.future),
        child: overview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(apiErrorMessage(error))],
          ),
          data: (overview) => _OverviewView(overview),
        ),
      ),
    );
  }
}

class _OverviewView extends ConsumerWidget {
  const _OverviewView(this.overview);

  final CashOverview overview;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    CashDeposit deposit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Mueve la plata: se pregunta antes, con quién, cuánto, adónde y cuándo.
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar depósito'),
        content: Text(confirmDepositQuestion(deposit)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('deposit-confirm-ok'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, llegó'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(cashRepositoryProvider).confirmDeposit(deposit.id);
      ref.invalidate(cashOverviewProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Depósito confirmado. Le avisamos.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  Future<void> _setCollector(
    BuildContext context,
    WidgetRef ref,
    CashCollector collector,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cashRepositoryProvider)
          .setCollectsToOrgCash(collector.userId, value);
      ref.invalidate(cashOverviewProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '${collector.name} cobra directo a la Caja. Lo que ya tiene '
                      'en su caja sigue ahí hasta que lo deposite.'
                : '${collector.name} rinde lo que cobra: queda en su caja '
                      'hasta que lo deposite.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    CashDeposit deposit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null) return;
    try {
      await ref.read(cashRepositoryProvider).rejectDeposit(deposit.id, reason);
      ref.invalidate(cashOverviewProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Depósito rechazado. Le avisamos.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En poder de quienes cobran',
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  formatMoney(overview.total),
                  style: theme.textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Por confirmar', style: theme.textTheme.titleMedium),
        if (overview.deposits.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No hay depósitos para confirmar.'),
          ),
        for (final deposit in overview.deposits)
          CashDepositTile(
            deposit,
            showHolder: true,
            onConfirm: () => _confirm(context, ref, deposit),
            onReject: () => _reject(context, ref, deposit),
          ),
        if (overview.collectors != null && overview.collectors!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Quién cobra directo a la Caja',
            style: theme.textTheme.titleMedium,
          ),
          const Text(
            'Lo que cobran en efectivo entra en la Caja del club, sin caja '
            'propia ni depósito. Los demás lo rinden: queda en su caja hasta '
            'que lo depositan.',
          ),
          for (final collector in overview.collectors!)
            SwitchListTile(
              key: Key('collector-${collector.userId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(collector.name),
              subtitle: Text(
                [
                  collector.collectsToOrgCash
                      ? 'Cobra directo a la Caja'
                      : 'Rinde lo que cobra',
                  if (collector.isOwner) 'creó la organización',
                ].join(' · '),
              ),
              value: collector.collectsToOrgCash,
              onChanged: (value) =>
                  _setCollector(context, ref, collector, value),
            ),
        ],
        const SizedBox(height: 16),
        Text('Cajas', style: theme.textTheme.titleMedium),
        if (overview.boxes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nadie tiene efectivo del club en su poder.'),
          ),
        for (final box in overview.boxes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(box.holderName),
            subtitle: Text(
              [
                if (!box.holderActive) 'Ya no está en el club',
                if (box.pendingDeposits > 0)
                  '${formatMoney(box.pendingDeposits)} por confirmar',
                if (box.lastMovementOn != null)
                  'Último movimiento: ${formatDate(box.lastMovementOn!)}',
              ].join(' · '),
              style: box.holderActive
                  ? null
                  : TextStyle(color: theme.colorScheme.error),
            ),
            trailing: Text(
              formatMoney(box.balance),
              style: theme.textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rechazar depósito'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const Key('deposit-reject-reason'),
        controller: _reason,
        autofocus: true,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Motivo',
          hintText: 'No llegó al banco, el monto no coincide…',
        ),
        validator: validateDepositRejection,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.of(context).pop(_reason.text.trim());
          }
        },
        child: const Text('Rechazar'),
      ),
    ],
  );
}
