import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../data/models.dart';
import '../data/payment_reports_repository.dart';
import '../data/report_form.dart';

/// Comprobantes de transferencia informados por los tutores, para aprobarlos
/// (registra el pago con su recibo) o rechazarlos con motivo.
class PaymentReportsScreen extends ConsumerStatefulWidget {
  const PaymentReportsScreen({super.key});

  @override
  ConsumerState<PaymentReportsScreen> createState() =>
      _PaymentReportsScreenState();
}

class _PaymentReportsScreenState extends ConsumerState<PaymentReportsScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(paymentReportsProvider(_all));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobantes de pago'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(paymentReportsProvider(_all).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Para revisar')),
                ButtonSegment(value: true, label: Text('Todos')),
              ],
              selected: {_all},
              onSelectionChanged: (value) => setState(() => _all = value.first),
            ),
            const SizedBox(height: 8),
            ...reports.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    apiErrorMessage(error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              data: (reports) => [
                if (reports.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _all
                          ? 'Todavía no hay comprobantes.'
                          : 'No hay comprobantes para revisar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final report in reports) _ReviewCard(report),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard(this.report);

  final PaymentReport report;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_Approval>(
      context: context,
      builder: (_) => _ApproveDialog(report),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(paymentReportsRepositoryProvider)
          .approve(
            report.id,
            moneyAccountId: result.moneyAccountId,
            receivedOn: result.receivedOn,
            amount: result.amount,
          ),
      (r) => 'Pago aprobado: recibo N° ${r.receiptNumber}.',
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () =>
          ref.read(paymentReportsRepositoryProvider).reject(report.id, reason),
      (_) => 'Comprobante rechazado. Le avisamos al tutor.',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<PaymentReport> Function() action,
    String Function(PaymentReport) message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await action();
      ref.invalidate(paymentReportsProvider);
      messenger.showSnackBar(SnackBar(content: Text(message(updated))));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final family = report.family;
    final proof = report.proofUrl;
    final receipt = report.receiptUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    family?.name ?? 'Familia',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  formatMoney(report.amount),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            Text(
              [
                if (family != null && family.students.isNotEmpty)
                  family.students.join(', '),
                if (report.reportedBy != null) 'Informó ${report.reportedBy}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              [
                'Transferencia del ${formatDate(report.paidOn)}',
                if (report.moneyAccount != null) report.moneyAccount!.name,
                if (report.reference != null) 'Ref. ${report.reference}',
              ].join(' · '),
            ),
            for (final charge in report.charges)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${charge.studentFirstName} · ${charge.description}',
                    ),
                  ),
                  Text(formatMoney(charge.pendingAmount)),
                ],
              ),
            if (report.charges.isEmpty) const Text('Pago a cuenta'),
            if (report.pendingBalance != null)
              Text(
                'La familia debe hoy ${formatMoney(report.pendingBalance!)}',
                style: theme.textTheme.bodySmall,
              ),
            if (report.notes != null) Text('Nota: ${report.notes}'),
            if (!report.isPending) ...[
              const SizedBox(height: 4),
              Text(
                report.status == PaymentReportStatus.approved
                    ? 'Aprobado · recibo N° ${report.receiptNumber}'
                    : 'Rechazado · ${report.rejectionReason ?? ''}',
                style: TextStyle(
                  color: report.status == PaymentReportStatus.approved
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (proof != null)
                  TextButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Ver comprobante'),
                    onPressed: () =>
                        ref.read(urlLauncherProvider)(Uri.parse(proof)),
                  ),
                if (receipt != null)
                  TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ver recibo'),
                    onPressed: () =>
                        ref.read(urlLauncherProvider)(Uri.parse(receipt)),
                  ),
                if (report.isPending) ...[
                  OutlinedButton(
                    onPressed: () => _reject(context, ref),
                    child: const Text('Rechazar'),
                  ),
                  FilledButton(
                    onPressed: () => _approve(context, ref),
                    child: const Text('Aprobar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Approval {
  const _Approval(this.moneyAccountId, this.receivedOn, this.amount);

  final int? moneyAccountId;
  final DateTime receivedOn;
  final int amount;
}

/// Confirma la cuenta donde entró la plata, la fecha y el monto.
class _ApproveDialog extends ConsumerStatefulWidget {
  const _ApproveDialog(this.report);

  final PaymentReport report;

  @override
  ConsumerState<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends ConsumerState<_ApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: '${widget.report.amount}');
  late int? _accountId = _initialAccount();
  late DateTime _receivedOn = widget.report.paidOn;

  int? _initialAccount() {
    final accounts = widget.report.moneyAccounts;
    final reported = widget.report.moneyAccount?.id;
    if (accounts.any((a) => a.id == reported)) return reported;
    return accounts.isEmpty ? null : accounts.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: _receivedOn,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (date != null) setState(() => _receivedOn = date);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Aprobar pago'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Se registra el pago por transferencia con su recibo y se imputa a las cuotas elegidas.',
          ),
          const SizedBox(height: 16),
          if (widget.report.moneyAccounts.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Entró en'),
              items: [
                for (final account in widget.report.moneyAccounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Fecha'),
              child: Text(formatDate(_receivedOn)),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Monto acreditado',
              prefixText: '₲ ',
            ),
            validator: validateReportAmount,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _Approval(_accountId, _receivedOn, int.parse(_amount.text)),
          );
        },
        child: const Text('Aprobar'),
      ),
    ],
  );
}

/// Pide el motivo, que le llega al tutor.
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
    title: const Text('Rechazar comprobante'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Motivo',
          hintText: 'El comprobante no se lee, el monto no coincide…',
        ),
        validator: validateRejectionReason,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _reason.text.trim());
        },
        child: const Text('Rechazar'),
      ),
    ],
  );
}
