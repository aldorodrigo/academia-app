import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../billing/presentation/charge_tile.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/withdrawals_repository.dart';
import 'dropout_reports.dart';

/// `/alumnos/:id`: ficha para quien da de baja (`withdraw_students`) o condona (`waive_charges`).
/// Inscripciones con "Dar de baja" y "Sigue viniendo"; cuenta con "Condonar" y "Deshacer".
class ManageStudentScreen extends ConsumerWidget {
  const ManageStudentScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(managedStudentProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(student.value?.fullName ?? 'Alumno'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
      ),
      body: student.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (student) => RefreshIndicator(
          onRefresh: () => ref.refresh(managedStudentProvider(id).future),
          child: _Details(student),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details(this.student);

  final ManagedStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final canWithdraw = organization?.can('withdraw_students') ?? false;
    final charges = student.charges;
    final waivable = charges?.where((c) => c.canWaive).toList() ?? const [];
    final waivableTotal = waivable.fold(
      0,
      (sum, c) => sum + c.charge.pendingAmount,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Inscripciones', style: theme.textTheme.titleMedium),
        if (student.enrollments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tiene inscripciones vigentes.'),
          ),
        for (final enrollment in student.enrollments)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          enrollment.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(enrollment.statusLabel),
                    ],
                  ),
                  if (enrollment.isWithdrawn && enrollment.endedOn != null)
                    Text(
                      'Baja el ${formatDate(enrollment.endedOn!)}'
                      '${enrollment.withdrawalReason == null ? '' : ': ${enrollment.withdrawalReason}'}',
                    ),
                  if (enrollment.dropoutReport != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        describeReport(
                          enrollment.dropoutReport!,
                          ref.watch(orgWordProvider),
                        ),
                        style: TextStyle(color: theme.colorScheme.tertiary),
                      ),
                    ),
                  if (canWithdraw &&
                      (enrollment.canWithdraw ||
                          enrollment.dropoutReport != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (enrollment.dropoutReport != null)
                            OutlinedButton(
                              onPressed: () =>
                                  _dismiss(context, ref, student, enrollment),
                              child: const Text('Sigue viniendo'),
                            ),
                          if (enrollment.canWithdraw)
                            FilledButton.tonal(
                              onPressed: () =>
                                  _withdraw(context, ref, student, enrollment),
                              child: const Text('Dar de baja'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (charges != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Cuenta', style: theme.textTheme.titleMedium),
              ),
              Text(
                'Debe ${formatMoney(student.balance)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (waivable.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _waive(
                  context,
                  ref,
                  student,
                  waivable.map((c) => c.charge.id).toList(),
                  waivableTotal,
                ),
                child: Text(
                  'Condonar todo lo pendiente (${formatMoney(waivableTotal)})',
                ),
              ),
            ),
          if (charges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No tiene cuotas.'),
            ),
          for (final item in charges) _ChargeRow(student, item),
        ],
      ],
    );
  }
}

class _ChargeRow extends ConsumerWidget {
  const _ChargeRow(this.student, this.item);

  final ManagedStudent student;
  final ManagedCharge item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = item.charge;
    final waiver = item.waiver;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(charge.description),
      subtitle: Text(
        waiver != null
            ? 'Condonado ${formatMoney(waiver.amount)} por ${waiver.by} '
                  'el ${formatDate(waiver.on)}: ${waiver.reason}'
            : 'Vence ${formatDate(charge.dueOn)} · '
                  'Falta ${formatMoney(charge.pendingAmount)}',
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ChargeStatusLabel(charge.status, upcoming: charge.isUpcoming),
          if (item.canWaive)
            InkWell(
              onTap: () => _waive(context, ref, student, [
                charge.id,
              ], charge.pendingAmount),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Condonar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          if (item.canUnwaive)
            InkWell(
              onTap: () => _unwaive(context, ref, student, item),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Deshacer',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dar de baja: fecha, motivo y, si hay tutores con la app, el aviso a la familia (prellenado,
/// amable y con las puertas abiertas; se puede cambiar antes de mandar).
class WithdrawForm extends ConsumerStatefulWidget {
  const WithdrawForm({
    super.key,
    required this.student,
    required this.enrollment,
  });

  final ManagedStudent student;
  final ManagedEnrollment enrollment;

  @override
  ConsumerState<WithdrawForm> createState() => _WithdrawFormState();
}

class _WithdrawFormState extends ConsumerState<WithdrawForm> {
  late final _reason = TextEditingController(
    text: widget.enrollment.dropoutReport?.note,
  );
  late final _message = TextEditingController(
    text: widget.student.noticeMessage,
  );
  late DateTime _endedOn = ref.read(todayProvider);
  late bool _notify = widget.student.noticeRecipients > 0;
  String? _reasonError;

  @override
  void dispose() {
    _reason.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final recipients = widget.student.noticeRecipients;

    return Scaffold(
      appBar: AppBar(title: Text('Dar de baja a ${widget.student.firstName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.enrollment.title),
          const SizedBox(height: 8),
          const Text(
            'Lo que debe (también la cuota de este mes) sigue en su cuenta hasta que '
            'se pague o se condone. Las cuotas futuras sin pagar se anulan.',
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha de baja'),
            subtitle: Text(formatDate(_endedOn)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endedOn,
                firstDate: DateTime(today.year - 1),
                lastDate: today,
              );
              if (picked != null) setState(() => _endedOn = picked);
            },
          ),
          TextField(
            controller: _reason,
            decoration: InputDecoration(
              labelText: 'Motivo',
              hintText:
                  'Ej.: se mudó, dejó de venir, cambió de '
                  '${ref.watch(orgWordProvider).word}',
              errorText: _reasonError,
            ),
            maxLength: 255,
          ),
          const SizedBox(height: 8),
          if (recipients == 0)
            const Text(
              'No tiene tutores con la app: si querés avisarle a la familia, '
              'hacelo por WhatsApp.',
            )
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisar a la familia'),
              subtitle: Text(
                recipients == 1
                    ? 'Le llega al tutor por la app y por correo.'
                    : 'Les llega a los $recipients tutores por la app y por correo.',
              ),
              value: _notify,
              onChanged: (value) => setState(() => _notify = value),
            ),
            if (_notify)
              TextField(
                controller: _message,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  helperText: 'Podés cambiarlo antes de mandarlo.',
                ),
                maxLines: 6,
                minLines: 3,
                maxLength: 1000,
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Dar de baja')),
        ],
      ),
    );
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Contanos el motivo de la baja.');
      return;
    }
    Navigator.pop(
      context,
      WithdrawalDraft(
        endedOn: _endedOn,
        reason: reason,
        notify: _notify,
        message: _notify ? _message.text : null,
      ),
    );
  }
}

Future<void> _withdraw(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  ManagedEnrollment enrollment,
) async {
  final draft = await Navigator.of(context).push<WithdrawalDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => WithdrawForm(student: student, enrollment: enrollment),
    ),
  );
  if (draft == null || !context.mounted) return;
  await _run(context, ref, student, () async {
    final notified = await ref
        .read(withdrawalsRepositoryProvider)
        .withdraw(enrollment.id, draft);
    return notified > 0
        ? 'Baja registrada. Le avisamos a la familia.'
        : 'Baja registrada.';
  });
}

Future<void> _dismiss(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  ManagedEnrollment enrollment,
) => _run(context, ref, student, () async {
  await ref.read(withdrawalsRepositoryProvider).dismissDropout(enrollment.id);
  return 'Listo: sacamos el aviso.';
});

Future<void> _waive(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  List<int> ids,
  int total,
) async {
  final reason = await askReason(
    context,
    title: 'Condonar ${formatMoney(total)}',
    action: 'Condonar',
    description:
        'Se perdona lo que falta pagar: deja de sumar en la cuenta, en Saldos y en Morosos. '
        'Queda registrado quién, cuándo y por qué, y se puede deshacer.',
    hint: 'Ej.: dado de baja, lo decidió la comisión',
  );
  if (reason == null || !context.mounted) return;
  await _run(context, ref, student, () async {
    final waived = await ref
        .read(withdrawalsRepositoryProvider)
        .waive(ids, reason);
    return 'Condonado: ${formatMoney(waived)}.';
  });
}

Future<void> _unwaive(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  ManagedCharge item,
) async {
  final reason = await askReason(
    context,
    title: 'Deshacer la condonación',
    action: 'Deshacer',
    description:
        'La cuota vuelve a quedar pendiente por ${formatMoney(item.waiver?.amount ?? 0)}.',
    hint: 'Ej.: se condonó por error',
  );
  if (reason == null || !context.mounted) return;
  await _run(context, ref, student, () async {
    await ref
        .read(withdrawalsRepositoryProvider)
        .unwaive(item.charge.id, reason);
    return 'Listo: la cuota vuelve a estar pendiente.';
  });
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  Future<String> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final done = await action();
    ref.invalidate(managedStudentProvider(student.id));
    ref.invalidate(dropoutReportsProvider);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
  }
}
