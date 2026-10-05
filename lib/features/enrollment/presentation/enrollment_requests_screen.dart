import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/models.dart';
import '../data/request_form.dart';
import '../../../core/widgets/error_view.dart';

/// Inscripciones que pidieron las familias desde la app: el chico ya va a
/// clases; confirmarla emite sus cuotas y rechazarla lo saca de la lista.
class EnrollmentRequestsScreen extends ConsumerStatefulWidget {
  const EnrollmentRequestsScreen({super.key});

  @override
  ConsumerState<EnrollmentRequestsScreen> createState() =>
      _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState
    extends ConsumerState<EnrollmentRequestsScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(enrollmentReviewProvider(_all));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de inscripción'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(enrollmentReviewProvider(_all).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Para revisar')),
                ButtonSegment(value: true, label: Text('Todas')),
              ],
              selected: {_all},
              onSelectionChanged: (value) => setState(() => _all = value.first),
            ),
            const SizedBox(height: 8),
            ...requests.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                ErrorView(
                  error,
                  onRetry: () => ref.invalidate(enrollmentReviewProvider(_all)),
                ),
              ],
              data: (requests) => [
                if (requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _all
                          ? 'Todavía no hay solicitudes.'
                          : 'No hay solicitudes para revisar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final request in requests) _ReviewCard(request),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard(this.request);

  final EnrollmentRequest request;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final groupTerm =
        ref.read(currentOrganizationProvider).value?.term('group') ??
        'Categoría';
    final result = await showDialog<_Approval>(
      context: context,
      builder: (_) => _ApproveDialog(request, groupTerm: groupTerm),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(enrollmentRepositoryProvider)
          .approve(
            request.id,
            groupId: result.groupId,
            midPeriod: result.midPeriod,
            overCapacity: result.overCapacity,
          ),
      (r) =>
          'Inscripción confirmada: ${r.child.firstName} en ${r.placeLabel}. '
          'Le avisamos a la familia.',
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const RejectRequestDialog(),
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(enrollmentRepositoryProvider).reject(request.id, reason),
      (_) => 'Solicitud rechazada. Le avisamos a la familia.',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<EnrollmentRequest> Function() action,
    String Function(EnrollmentRequest) message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await action();
      ref.invalidate(enrollmentReviewProvider);
      messenger.showSnackBar(SnackBar(content: Text(message(updated))));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final child = request.child;
    final requester = request.requestedBy;
    final existing = request.existingStudent;
    final spots = request.groupOption(request.group.id)?.spotsLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(child.fullName, style: theme.textTheme.titleSmall),
            Text(
              [
                if (request.age != null) '${request.age} años',
                'Nació el ${formatDate(child.birthDate)}',
                if (child.document != null) 'Doc. ${child.document}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text([request.placeLabel, ?spots].join(' · ')),
            if (requester != null)
              Text(
                [
                  'Pidió ${requester.name} (${request.relationship.label.toLowerCase()})',
                  ?requester.contact,
                ].join(' · '),
              ),
            if (existing != null)
              Text(
                'Ya estaba cargado: ${existing.fullName}'
                '${existing.guardians.isEmpty ? '' : ' (tutores: ${existing.guardians.join(', ')})'}. '
                'Al confirmar se le suma este tutor.',
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            if (request.hasMedical)
              Text('Cargó la ficha médica.', style: theme.textTheme.bodySmall),
            if (request.notes != null) Text('Nota: ${request.notes}'),
            if (!request.isPending) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (request.status == EnrollmentRequestStatus.rejected)
                    'No aprobada · ${request.rejectionReason ?? ''}'
                  else
                    request.status.label,
                  if (request.selfApproved)
                    'se confirmó sola'
                  else if (request.reviewedBy != null)
                    request.reviewedBy!,
                ].join(' · '),
                style: TextStyle(
                  color: request.status == EnrollmentRequestStatus.approved
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _reject(context, ref),
                    child: const Text('Rechazar'),
                  ),
                  FilledButton(
                    onPressed: () => _approve(context, ref),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Approval {
  const _Approval(this.groupId, this.midPeriod, this.overCapacity);

  final int groupId;
  final String? midPeriod;
  final bool overCapacity;
}

/// La categoría, qué se cobra del mes en curso y, si está llena, el cupo.
class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog(this.request, {required this.groupTerm});

  final EnrollmentRequest request;
  final String groupTerm;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late int _groupId = widget.request.group.id;
  late String? _midPeriod = widget.request.midPeriod?.defaultValue;
  bool _overCapacity = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final options = request.groupOptions;
    final selected = request.groupOption(_groupId);
    final full = selected?.full ?? false;
    final midPeriod = request.midPeriod;

    return AlertDialog(
      title: const Text('Confirmar inscripción'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${request.child.firstName} ya va a clases. Al confirmar se '
              'emiten sus cuotas según el plan de la temporada '
              '${request.season.name}.',
            ),
            const SizedBox(height: 16),
            if (options.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _groupId,
                decoration: InputDecoration(labelText: widget.groupTerm),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        [
                          option.name,
                          if (option.suggested) '(por edad)',
                          if (option.spotsLabel != null)
                            '· ${option.spotsLabel}',
                        ].join(' '),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _groupId = value ?? _groupId;
                  _overCapacity = false;
                }),
              ),
            if (midPeriod != null) ...[
              const SizedBox(height: 16),
              Text(midPeriod.label),
              RadioGroup<String>(
                groupValue: _midPeriod,
                onChanged: (value) => setState(() => _midPeriod = value),
                child: Column(
                  children: [
                    for (final choice in midPeriod.options)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: choice.value,
                        title: Text(choice.label),
                      ),
                  ],
                ),
              ),
            ],
            if (full)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _overCapacity,
                onChanged: (value) =>
                    setState(() => _overCapacity = value ?? false),
                title: Text(
                  '${selected!.name} está completa. Inscribir igual.',
                ),
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
          onPressed: full && !_overCapacity
              ? null
              : () => Navigator.pop(
                  context,
                  _Approval(_groupId, _midPeriod, _overCapacity),
                ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// Pide el motivo, que le llega a la familia. Lo usa también la planilla.
class RejectRequestDialog extends StatefulWidget {
  const RejectRequestDialog({super.key});

  @override
  State<RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<RejectRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rechazar inscripción'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Motivo',
          hintText: 'No hay lugar este año, falta un dato…',
        ),
        validator: validateRequestRejection,
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
