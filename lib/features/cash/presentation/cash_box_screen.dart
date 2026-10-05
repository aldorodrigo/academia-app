import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../../organizations/data/organization_repository.dart';
import '../../../core/widgets/error_view.dart';
import '../data/cash_form.dart';
import '../data/cash_repository.dart';
import '../data/models.dart';
import 'cash_deposit_tile.dart';

/// "Mi caja": la plata del club que tiene quien cobra en efectivo, sus
/// movimientos y "Depositar" (queda por confirmar hasta que lo confirma
/// alguien que valida los comprobantes; la API manda quiénes).
class CashBoxScreen extends ConsumerWidget {
  const CashBoxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final box = ref.watch(cashBoxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi caja'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(cashBoxProvider.future),
        child: box.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              ErrorView(error, onRetry: () => ref.invalidate(cashBoxProvider)),
            ],
          ),
          data: (box) => _CashBoxView(box),
        ),
      ),
    );
  }
}

class _CashBoxView extends ConsumerWidget {
  const _CashBoxView(this.box);

  final CashBox box;

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    CashDeposit deposit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(cashRepositoryProvider).withdrawDeposit(deposit.id);
      ref.invalidate(cashBoxProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Retiraste el depósito.')),
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
                Text('En tu poder', style: theme.textTheme.labelLarge),
                Text(
                  formatMoney(box.balance),
                  style: theme.textTheme.headlineMedium,
                ),
                if (box.pendingDeposits > 0)
                  Text(
                    '${formatMoney(box.pendingDeposits)} por confirmar · '
                    '${formatMoney(box.available)} para depositar',
                    style: theme.textTheme.bodySmall,
                  ),
                if (box.name != null)
                  Text(box.name!, style: theme.textTheme.bodySmall),
                if (!box.active)
                  Text(
                    '${closedBoxMessage(box.reopeners, ref.watch(orgWordProvider))} '
                    'Mientras tanto no podés cobrar, pero sí depositar.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('Depositar'),
                      onPressed: box.canDeposit
                          ? () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => DepositSheet(box),
                            )
                          : null,
                    ),
                    if (box.active)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Cobrar'),
                        onPressed: () => context.go('/cobrar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (box.deposits.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Depósitos', style: theme.textTheme.titleMedium),
          for (final deposit in box.deposits)
            CashDepositTile(
              deposit,
              onWithdraw: deposit.isPending
                  ? () => _withdraw(context, ref, deposit)
                  : null,
            ),
        ],
        const SizedBox(height: 16),
        Text('Movimientos', style: theme.textTheme.titleMedium),
        if (box.movements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no cobraste nada. Lo que cobres en efectivo aparece acá.',
            ),
          ),
        for (final movement in box.movements) _MovementTile(movement),
      ],
    );
  }
}

class _MovementTile extends ConsumerWidget {
  const _MovementTile(this.movement);

  final CashMovement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final url = movement.receiptUrl;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (movement.kind) {
        CashMovementKind.collection => Icons.south_west,
        CashMovementKind.deposit => Icons.north_east,
        CashMovementKind.reversal => Icons.undo,
        CashMovementKind.other => Icons.swap_horiz,
      }),
      title: Text(movement.description),
      subtitle: Text(formatDate(movement.occurredOn)),
      trailing: Text(
        movement.amount > 0
            ? '+${formatMoney(movement.amount)}'
            : formatMoney(movement.amount),
        style: theme.textTheme.titleSmall,
      ),
      onTap: url == null
          ? null
          : () => ref.read(urlLauncherProvider)(Uri.parse(url)),
    );
  }
}

/// "Depositar": cuánto, dónde, cuándo y el N° de boleta.
class DepositSheet extends ConsumerStatefulWidget {
  const DepositSheet(this.box, {super.key});

  final CashBox box;

  @override
  ConsumerState<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<DepositSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: '${widget.box.available}');
  final _reference = TextEditingController();
  late int? _accountId = widget.box.depositAccounts.length == 1
      ? widget.box.depositAccounts.single.id
      : null;
  late DateTime _depositedOn = ref.read(todayProvider);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: _depositedOn,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (date != null) setState(() => _depositedOn = date);
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(cashRepositoryProvider)
          .deposit(
            DepositDraft(
              amount: int.parse(_amount.text.trim()),
              moneyAccountId: _accountId!,
              depositedOn: _depositedOn,
              reference: _reference.text,
            ),
          );
      ref.invalidate(cashBoxProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listo. Te avisamos cuando lo confirmen.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = apiErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = widget.box.depositAccounts;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Depositar', style: theme.textTheme.titleLarge),
              Text(
                'Tenés ${formatMoney(widget.box.available)} para depositar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('deposit-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // Viene con todo lo que tiene para depositar; se puede cambiar.
                // (El texto de ayuda lo repite: en la web, el lector de
                // pantalla no lee el valor del campo.)
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '₲ ',
                  helperText:
                      'Puesto: todo lo que tenés '
                      '(${formatMoney(widget.box.available)}). Podés cambiarlo.',
                ),
                validator: (v) =>
                    validateDepositAmount(v, widget.box.available),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('deposit-account'),
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: '¿Dónde lo dejaste?',
                ),
                items: [
                  for (final account in accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                validator: validateDepositAccount,
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(formatDate(_depositedOn)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reference,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'N° de boleta o de operación (opcional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: const Text('Informar depósito'),
              ),
              const SizedBox(height: 8),
              Text(
                'La plata sigue en tu caja '
                '${untilConfirmed(widget.box.confirmers, ref.watch(orgWordProvider))}.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
