import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/clock.dart';
import '../../billing/data/amount_hint.dart';
import '../../billing/data/models.dart';
import '../../payment_reports/data/report_form.dart';
import '../../payment_reports/presentation/proof_field.dart';
import '../data/cash_form.dart';
import '../data/cash_repository.dart';
import '../data/models.dart';
import '../../organizations/data/organization_repository.dart';

/// Cobrar a un alumno: cuotas pendientes de su familia, monto prellenado con
/// lo elegido, quién pagó y el recibo. En efectivo entra en la caja de quien
/// cobra; con "Transferencia" se registra la captura que la familia le mandó
/// (aprobada con recibo si valida comprobantes, si no en revisión).
class CollectScreen extends ConsumerWidget {
  const CollectScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(collectionTargetProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(target.value?.studentName ?? 'Cobrar'),
        leading: BackButton(onPressed: () => _back(context)),
      ),
      body: target.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (target) => _CollectForm(target),
      ),
    );
  }
}

/// Vuelve a donde se abrió (la lista o el grupo); en un link directo, a la lista.
void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/cobrar');

class _CollectForm extends ConsumerStatefulWidget {
  const _CollectForm(this.target);

  final CollectionTarget target;

  @override
  ConsumerState<_CollectForm> createState() => _CollectFormState();
}

class _CollectFormState extends ConsumerState<_CollectForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  late final Set<int> _selected = initialSelection(widget.target);
  late int? _guardianId = widget.target.guardians.length == 1
      ? widget.target.guardians.single.id
      : null;

  /// Uno por cobro: si se reintenta, la API no lo registra dos veces.
  late final String _requestId = ref.read(collectionRequestIdProvider)();
  bool _amountEdited = false;
  bool _sending = false;
  String? _error;

  /// Efectivo o la transferencia que la familia le mandó.
  bool _transfer = false;
  late DateTime _paidOn = ref.read(todayProvider);
  late int? _accountId = widget.target.transferAccounts.length == 1
      ? widget.target.transferAccounts.single.id
      : null;
  final _reference = TextEditingController();

  /// Si cobra directo a la Caja: la cuenta del club donde entra el efectivo.
  late int? _cashAccountId =
      widget.target.defaultCollectAccountId ??
      (widget.target.collectAccounts.isEmpty
          ? null
          : widget.target.collectAccounts.first.id);
  PickedProof? _proof;
  String? _proofError;

  @override
  void initState() {
    super.initState();
    _syncAmount();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    _reference.dispose();
    super.dispose();
  }

  int get _selectedTotal => suggestedCollectAmount(
    widget.target.charges.where((c) => _selected.contains(c.id)),
  );

  /// Mientras no lo cambie, el monto es lo que salda hoy lo elegido.
  void _syncAmount() {
    if (_amountEdited) return;
    final total = _selectedTotal;
    _amount.text = total > 0 ? '$total' : '';
  }

  void _toggle(CollectableCharge charge, bool selected) => setState(() {
    selected ? _selected.add(charge.id) : _selected.remove(charge.id);
    _syncAmount();
  });

  Future<void> _collect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(cashRepositoryProvider)
          .collect(
            CollectionDraft(
              studentId: widget.target.studentId,
              amount: int.parse(_amount.text.trim()),
              requestId: _requestId,
              chargeIds: [
                for (final c in widget.target.charges)
                  if (_selected.contains(c.id)) c.id,
              ],
              guardianId: _guardianId,
              notes: _notes.text,
              moneyAccountId: widget.target.collectsToOrgCash
                  ? _cashAccountId
                  : null,
            ),
          );
      ref
        ..invalidate(collectableStudentsProvider)
        ..invalidate(cashBoxProvider)
        ..invalidate(collectionTargetProvider(widget.target.studentId));
      if (!mounted) return;
      setState(() => _sending = false);
      await showDialog<void>(
        context: context,
        builder: (_) => CollectionDoneDialog(result),
      );
      if (mounted) _back(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = apiErrorMessage(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (date != null) setState(() => _paidOn = date);
  }

  Future<void> _pickProof() async {
    final proof = await ref.read(proofPickerProvider)();
    if (proof == null) return;
    setState(() {
      _proof = proof;
      _proofError = validateProof(proof);
    });
  }

  Future<void> _registerTransfer() async {
    final proofError = validateProof(_proof);
    final valid = _formKey.currentState!.validate();
    setState(() => _proofError = proofError);
    if (!valid || proofError != null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(cashRepositoryProvider)
          .registerTransfer(
            TransferRegistrationDraft(
              studentId: widget.target.studentId,
              amount: int.parse(_amount.text.trim()),
              paidOn: _paidOn,
              proof: _proof!,
              chargeIds: [
                for (final c in widget.target.charges)
                  if (_selected.contains(c.id)) c.id,
              ],
              moneyAccountId: _accountId,
              guardianId: _guardianId,
              reference: _reference.text,
            ),
          );
      ref
        ..invalidate(collectableStudentsProvider)
        ..invalidate(collectionTargetProvider(widget.target.studentId));
      if (!mounted) return;
      setState(() => _sending = false);
      await showDialog<void>(
        context: context,
        builder: (_) => TransferDoneDialog(result),
      );
      if (mounted) _back(context);
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
    final target = widget.target;
    final showStudent = target.familyStudents.length > 1;
    final due = target.dueCharges;
    final upcoming = target.upcomingCharges;
    final hint = collectHint(int.tryParse(_amount.text), _selectedTotal);
    final box = target.cashBox;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (target.familyName != null)
            Text(
              [
                target.familyName!,
                if (showStudent) target.familyStudents.join(', '),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          if (target.credit > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tiene ${formatMoney(target.credit)} a favor.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Efectivo'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Transferencia'),
                icon: Icon(Icons.account_balance_outlined),
              ),
            ],
            selected: {_transfer},
            onSelectionChanged: _sending
                ? null
                : (value) => setState(() {
                    _transfer = value.single;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 16),
          Text('¿Qué paga?', style: theme.textTheme.titleMedium),
          if (target.charges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tiene cuotas pendientes: lo que cobres queda a favor de la familia.',
              ),
            ),
          for (final charge in due) _chargeTile(charge, showStudent),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Próximas cuotas', style: theme.textTheme.labelLarge),
            for (final charge in upcoming) _chargeTile(charge, showStudent),
          ],
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('collect-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _transfer
                  ? 'Monto transferido'
                  : 'Monto cobrado en efectivo',
              prefixText: '₲ ',
              helperText: hint,
              helperMaxLines: 3,
            ),
            validator: _transfer ? validateReportAmount : validateCollectAmount,
            onChanged: (value) => setState(
              () => _amountEdited = amountEditedByHand(value, _selectedTotal),
            ),
          ),
          if (target.guardians.length > 1) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _guardianId,
              decoration: InputDecoration(
                labelText: _transfer ? '¿Quién la mandó?' : '¿Quién pagó?',
              ),
              items: [
                for (final guardian in target.guardians)
                  DropdownMenuItem(
                    value: guardian.id,
                    child: Text(guardian.fullName),
                  ),
              ],
              onChanged: (value) => setState(() => _guardianId = value),
            ),
          ],
          if (_transfer)
            ..._transferFields()
          else ...[
            if (target.collectsToOrgCash &&
                target.collectAccounts.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('collect-account'),
                initialValue: _cashAccountId,
                decoration: const InputDecoration(labelText: '¿Dónde entra?'),
                items: [
                  for (final account in target.collectAccounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => _cashAccountId = value),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          if (_transfer) ...[
            FilledButton.icon(
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Registrar transferencia'),
              onPressed: _sending ? null : _registerTransfer,
            ),
            const SizedBox(height: 8),
            Text(
              target.approvesTransfers
                  ? 'Se registra el pago con su recibo y le avisamos a la familia.'
                  : 'Queda en revisión hasta que la apruebe el tesorero. '
                        'La familia la ve en su estado de cuenta.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ] else if (!target.canCollect)
            Text(
              'Tu caja está cerrada. Hablá con el tesorero.',
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            )
          else
            FilledButton.icon(
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: Text(
                (int.tryParse(_amount.text) ?? 0) > 0
                    ? 'Cobrar ${formatMoney(int.parse(_amount.text))}'
                    : 'Cobrar',
              ),
              onPressed: _sending ? null : _collect,
            ),
          if (!_transfer) ...[
            const SizedBox(height: 8),
            Text(
              target.collectsToOrgCash
                  ? 'Entra directo en ${_cashAccountName(target) ?? 'la Caja ${ref.watch(orgWordProvider).of()}'}: '
                        'no tenés que depositarlo. La familia recibe el recibo.'
                  : box == null
                  ? 'Queda en tu caja hasta que lo deposites en la cuenta '
                        '${ref.watch(orgWordProvider).of()}. '
                        'La familia recibe el recibo.'
                  : 'Queda en tu caja (${formatMoney(box.balance)} en tu poder) '
                        'hasta que lo deposites. La familia recibe el recibo.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String? _cashAccountName(CollectionTarget target) {
    for (final account in target.collectAccounts) {
      if (account.id == _cashAccountId) return account.name;
    }
    return null;
  }

  /// Fecha, cuenta, N° de operación y la captura o el PDF.
  List<Widget> _transferFields() {
    final accounts = widget.target.transferAccounts;
    return [
      const SizedBox(height: 16),
      InkWell(
        onTap: _sending ? null : _pickDate,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha de la transferencia',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(formatDate(_paidOn)),
        ),
      ),
      if (accounts.length > 1) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const Key('collect-account'),
          initialValue: _accountId,
          decoration: const InputDecoration(
            labelText: '¿A qué cuenta transfirió?',
          ),
          items: [
            for (final account in accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _reference,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'N° de operación (opcional)',
        ),
      ),
      const SizedBox(height: 8),
      ProofField(
        proof: _proof,
        error: _proofError,
        onPick: _sending ? null : _pickProof,
        hint: 'La captura que te mandaron por WhatsApp o el PDF, hasta 5 MB.',
      ),
    ];
  }

  Widget _chargeTile(CollectableCharge item, bool showStudent) {
    final charge = item.charge;
    final scheme = Theme.of(context).colorScheme;
    final notes = [
      if (charge.status == ChargeStatus.overdue)
        'Vencido'
      else
        'Vence el ${formatDate(charge.dueOn)}',
      if (charge.isPartiallyPaid)
        'pagado ${formatMoney(charge.paidAmount)} de ${formatMoney(charge.finalAmount)}',
      if (item.earlyPaymentLabel != null) item.earlyPaymentLabel!,
      if (item.underReview) 'Transferencia en revisión',
    ];

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selected.contains(item.id),
      onChanged: _sending ? null : (v) => _toggle(item, v ?? false),
      title: Text(
        showStudent
            ? '${charge.studentFirstName} · ${charge.description}'
            : charge.description,
      ),
      subtitle: Text(
        notes.join(' · '),
        style: charge.status == ChargeStatus.overdue || item.underReview
            ? TextStyle(color: scheme.error)
            : null,
      ),
      secondary: Text(formatMoney(item.settleAmount)),
    );
  }
}

/// Resultado del cobro: monto, recibo y saldo a favor.
class CollectionDoneDialog extends ConsumerWidget {
  const CollectionDoneDialog(this.result, {super.key});

  final CollectionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = result.payment.receiptUrl;
    return AlertDialog(
      icon: const Icon(Icons.check_circle_outline),
      title: Text('Cobrado ${formatMoney(result.payment.amount)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recibo N° ${result.payment.receiptNumber}'),
          if (result.credit > 0)
            Text('Quedan ${formatMoney(result.credit)} a favor de la familia.'),
          if (result.cashBox != null)
            Text('En tu caja: ${formatMoney(result.cashBox!.balance)}.')
          else if (result.accountName != null)
            Text('Entró en ${result.accountName}.'),
          const SizedBox(height: 8),
          const Text('Le avisamos a la familia con el recibo.'),
        ],
      ),
      actions: [
        if (url != null)
          TextButton(
            onPressed: () => ref.read(urlLauncherProvider)(Uri.parse(url)),
            child: const Text('Ver recibo'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

/// Resultado de registrar la transferencia: aprobada con recibo o en revisión.
class TransferDoneDialog extends ConsumerWidget {
  const TransferDoneDialog(this.result, {super.key});

  final TransferRegistration result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = result.report;
    final url = report.receiptUrl;
    return AlertDialog(
      icon: Icon(
        report.isPending ? Icons.hourglass_top : Icons.check_circle_outline,
      ),
      title: Text(
        report.isPending ? 'Enviada a revisión' : 'Transferencia registrada',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatMoney(report.amount)} · ${report.chargesSummary}'),
          const SizedBox(height: 8),
          Text(result.message),
        ],
      ),
      actions: [
        if (url != null)
          TextButton(
            onPressed: () => ref.read(urlLauncherProvider)(Uri.parse(url)),
            child: const Text('Ver recibo'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
