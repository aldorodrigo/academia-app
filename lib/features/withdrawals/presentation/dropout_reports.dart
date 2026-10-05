import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/withdrawals_repository.dart';
import '../../../core/vocabulary/vocabulary.dart';
import '../../../core/widgets/error_view.dart';

/// Tarjeta del inicio para quien da de baja: avisos del técnico o del tutor sin decidir.
class DropoutReportsCard extends ConsumerWidget {
  const DropoutReportsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref
            .watch(currentOrganizationProvider)
            .value
            ?.can('withdraw_students') ??
        false;
    if (!allowed) return const SizedBox.shrink();

    final reports = ref.watch(dropoutReportsProvider).value ?? const [];
    if (reports.isEmpty) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: Badge(
          label: Text('${reports.length}'),
          child: const Icon(Icons.person_off_outlined),
        ),
        title: const Text('Avisos de baja'),
        subtitle: Text(
          reports.length == 1
              ? '${reports.single.studentName} · '
                    '${reports.single.summaryFor(ref.watch(orgWordProvider))}'
              : '${reports.length} para decidir',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/bajas'),
      ),
    );
  }
}

/// `/bajas`: avisos de que un alumno dejó de venir o deja el club. Cada uno lleva a su ficha,
/// donde se da la baja o se descarta el aviso.
class DropoutReportsScreen extends ConsumerWidget {
  const DropoutReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(dropoutReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos de baja'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error,
          onRetry: () => ref.invalidate(dropoutReportsProvider),
        ),
        data: (reports) => RefreshIndicator(
          onRefresh: () => ref.refresh(dropoutReportsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay avisos para decidir.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final report in reports)
                Card(
                  child: ListTile(
                    title: Text(
                      [report.studentName ?? '', ?report.group].join(' · '),
                    ),
                    subtitle: Text(
                      [
                        '${report.summaryFor(ref.watch(orgWordProvider))} '
                            '(${formatDate(report.reportedOn)})',
                        if (report.note != null) '«${report.note}»',
                      ].join('\n'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: report.studentId == null
                        ? null
                        : () => context.push('/alumnos/${report.studentId}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje al tutor que avisa que su hijo deja el club, o null si cancela.
class LeavingDialog extends StatefulWidget {
  const LeavingDialog({
    super.key,
    required this.name,
    required this.organization,
  });

  final String name;

  /// Qué es la organización ("el club", "la academia").
  final Word organization;

  @override
  State<LeavingDialog> createState() => _LeavingDialogState();
}

class _LeavingDialogState extends State<LeavingDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('¿${widget.name} deja ${widget.organization.the()}?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le avisamos ${widget.organization.to()} para que registre la baja. '
          'Lo que esté pendiente de pago sigue en tu estado de cuenta.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          decoration: InputDecoration(
            labelText: 'Mensaje para ${widget.organization.the()} (opcional)',
            hintText: 'Ej.: nos mudamos, gracias por todo',
          ),
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _message.text),
        child: Text('Avisar ${widget.organization.to()}'),
      ),
    ],
  );
}

/// Pide un texto obligatorio (motivo). Devuelve null si se cancela.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String action,
  String? description,
  String hint = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _ReasonDialog(
    title: title,
    action: action,
    description: description,
    hint: hint,
  ),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.action,
    required this.hint,
    this.description,
  });

  final String title;
  final String action;
  final String hint;
  final String? description;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.description != null) ...[
          Text(widget.description!),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _reason,
          decoration: InputDecoration(
            labelText: 'Motivo',
            hintText: widget.hint,
            errorText: _error,
          ),
          maxLength: 255,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final reason = _reason.text.trim();
          if (reason.isEmpty) {
            setState(() => _error = 'Contanos el motivo.');
            return;
          }
          Navigator.pop(context, reason);
        },
        child: Text(widget.action),
      ),
    ],
  );
}

/// Para mostrar quién avisó en la ficha: "Carlos Gómez avisó que dejó de venir (03/06/2026)".
String describeReport(DropoutReport report, Word organization) =>
    '${report.summaryFor(organization)} (${formatDate(report.reportedOn)})'
    '${report.note == null ? '' : ': «${report.note}»'}';
