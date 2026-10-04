import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../billing/data/account_repository.dart';
import '../../billing/data/models.dart';
import '../data/models.dart';
import '../data/payment_reports_repository.dart';
import '../data/report_form.dart';

/// El tutor informa una transferencia: datos para transferir, qué cuotas paga,
/// monto, fecha y el comprobante (foto o PDF). Queda en revisión.
class ReportPaymentScreen extends ConsumerWidget {
  const ReportPaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informar transferencia'),
        leading: BackButton(onPressed: () => context.go('/estado-de-cuenta')),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (account) => _ReportForm(account),
      ),
    );
  }
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm(this.account);

  final Account account;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final List<Charge> _charges = reportableCharges(widget.account);
  late final Set<int> _selected = {
    for (final c in _charges)
      if (!c.isUpcoming) c.id,
  };
  late DateTime _paidOn = ref.read(todayProvider);
  late int? _accountId = widget.account.transferAccounts.length == 1
      ? widget.account.transferAccounts.single.id
      : null;
  PickedProof? _proof;
  String? _proofError;
  String? _error;
  bool _amountEdited = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _syncAmount();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  /// Mientras el tutor no lo cambie, el monto es lo que falta de las cuotas elegidas.
  void _syncAmount() {
    if (_amountEdited) return;
    final total = suggestedAmount(
      _charges.where((c) => _selected.contains(c.id)),
    );
    _amount.text = total > 0 ? '$total' : '';
  }

  void _toggle(Charge charge, bool selected) => setState(() {
    selected ? _selected.add(charge.id) : _selected.remove(charge.id);
    _syncAmount();
  });

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

  Future<void> _send() async {
    final proofError = validateProof(_proof);
    final valid = _formKey.currentState!.validate();
    setState(() => _proofError = proofError);
    if (!valid || proofError != null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(paymentReportsRepositoryProvider)
          .report(
            PaymentReportDraft(
              amount: int.parse(_amount.text.trim()),
              paidOn: _paidOn,
              proof: _proof!,
              chargeIds: [
                for (final c in _charges)
                  if (_selected.contains(c.id)) c.id,
              ],
              moneyAccountId: _accountId,
              reference: _reference.text,
            ),
          );
      ref.invalidate(accountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo. Te avisamos cuando lo revisen.')),
      );
      context.go('/estado-de-cuenta');
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
    final accounts = widget.account.transferAccounts;
    final showStudent = widget.account.students.length > 1;
    final due = _charges.where((c) => !c.isUpcoming).toList();
    final upcoming = _charges.where((c) => c.isUpcoming).toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (accounts.any((a) => a.details != null)) ...[
            Text('Datos para transferir', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final account in accounts)
              if (account.details != null) _TransferAccountCard(account),
            const SizedBox(height: 16),
          ],
          Text('¿Qué pagás?', style: theme.textTheme.titleMedium),
          if (_charges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tenés cuotas para pagar: lo que transfieras queda como saldo a favor.',
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
            key: const Key('report-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Monto transferido',
              prefixText: '₲ ',
            ),
            validator: validateReportAmount,
            onChanged: (_) => _amountEdited = true,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
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
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: '¿A qué cuenta transferiste?',
              ),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'N° de operación (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          _ProofField(
            proof: _proof,
            error: _proofError,
            onPick: _sending ? null : _pickProof,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar comprobante'),
            onPressed: _sending ? null : _send,
          ),
          const SizedBox(height: 8),
          Text(
            'El club revisa el comprobante y registra el pago. Te avisamos cuando esté listo.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _chargeTile(Charge charge, bool showStudent) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: _selected.contains(charge.id),
    onChanged: _sending ? null : (v) => _toggle(charge, v ?? false),
    title: Text(
      showStudent
          ? '${charge.studentFirstName} · ${charge.description}'
          : charge.description,
    ),
    subtitle: charge.status == ChargeStatus.overdue
        ? Text(
            'Vencido',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        : Text('Vence el ${formatDate(charge.dueOn)}'),
    secondary: Text(formatMoney(charge.pendingAmount)),
  );
}

/// Cuenta con sus datos y un botón para copiarlos.
class _TransferAccountCard extends StatelessWidget {
  const _TransferAccountCard(this.account);

  final TransferAccount account;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(account.name),
      subtitle: SelectableText(account.details!),
      trailing: IconButton(
        tooltip: 'Copiar datos',
        icon: const Icon(Icons.copy_outlined),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: '${account.name}\n${account.details}'),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Datos copiados.')));
        },
      ),
    ),
  );
}

/// Botón para adjuntar el comprobante y el archivo elegido.
class _ProofField extends StatelessWidget {
  const _ProofField({
    required this.proof,
    required this.error,
    required this.onPick,
  });

  final PickedProof? proof;
  final String? error;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = proof;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file == null)
          OutlinedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Adjuntar comprobante'),
            onPressed: onPick,
          )
        else
          Card(
            child: ListTile(
              leading: Icon(
                file.name.toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
              ),
              title: Text(file.name),
              subtitle: Text(_size(file.bytes.length)),
              trailing: TextButton(
                onPressed: onPick,
                child: const Text('Cambiar'),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          )
        else if (file == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'Captura o PDF de la transferencia, hasta 5 MB.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
