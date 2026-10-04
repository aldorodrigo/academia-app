import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import 'attendance_status_style.dart';

/// Menú de cada alumno del grupo.
enum _StudentAction { report, cancel, open }

/// Grupo del técnico: clases del mes y asistencia por alumno.
class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final month = _month ?? DateTime(today.year, today.month);
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final value = ref.watch(
      groupAttendanceProvider((id: widget.id, month: month)),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.group.name ?? 'Grupo'),
        leading: BackButton(onPressed: () => context.go('/grupos')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _month = DateTime(month.year, month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  formatPeriod(apiMonth(month)),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth
                    ? null
                    : () => setState(
                        () => _month = DateTime(month.year, month.month + 1),
                      ),
              ),
            ],
          ),
          ...value.when(
            loading: () => const [LinearProgressIndicator()],
            error: (error, _) => [Text(apiErrorMessage(error))],
            data: (data) => _details(context, data, today),
          ),
        ],
      ),
    );
  }

  List<Widget> _details(
    BuildContext context,
    GroupAttendance data,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final manages =
        (organization?.can('withdraw_students') ?? false) ||
        (organization?.can('waive_charges') ?? false);
    return [
      const SizedBox(height: 8),
      Text('Clases', style: theme.textTheme.titleMedium),
      if (data.classes.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No hubo clases este mes.'),
        ),
      for (final session in data.classes)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${formatShortDay(session.date, today)} · '
            '${session.timeDescription}'
            '${session.isMakeup ? ' · Recuperación' : ''}',
          ),
          subtitle: Text(
            session.rescheduled
                ? 'Reprogramada${session.rescheduledTo == null ? '' : ': ${session.rescheduledTo!.describe(today)}'}'
                : session.suspended
                ? 'Suspendida${session.suspensionReason == null ? '' : ': ${session.suspensionReason}'}'
                : session.attendanceTaken
                ? '${session.counts.present} presentes · '
                      '${session.counts.absent} ausentes · '
                      '${session.counts.justified} justificados'
                : 'Asistencia sin tomar',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/clases/${session.id}'),
        ),
      const SizedBox(height: 16),
      Text('Asistencia por alumno', style: theme.textTheme.titleMedium),
      for (final student in data.students)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            foregroundImage: student.photoUrl == null
                ? null
                : NetworkImage(student.photoUrl!),
            child: Text(student.initials),
          ),
          title: Text(student.fullName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final (status, count) in [
                    (AttendanceStatus.present, student.present),
                    (AttendanceStatus.absent, student.absent),
                    (AttendanceStatus.justified, student.justified),
                  ]) ...[
                    Icon(
                      status.icon,
                      size: 16,
                      color: status.color(theme.colorScheme),
                    ),
                    Text(' $count   '),
                  ],
                ],
              ),
              if (student.dropoutReportedOn != null)
                Text(
                  'Avisaste que dejó de venir el '
                  '${formatDate(student.dropoutReportedOn!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                student.rate == null ? '—' : '${student.rate}%',
                style: theme.textTheme.titleMedium,
              ),
              PopupMenuButton<_StudentAction>(
                tooltip: 'Más opciones de ${student.fullName}',
                onSelected: (action) => switch (action) {
                  _StudentAction.report => _reportDropout(data, student),
                  _StudentAction.cancel => _cancelDropout(data, student),
                  _StudentAction.open => context.push('/alumnos/${student.id}'),
                },
                itemBuilder: (_) => [
                  if (manages)
                    const PopupMenuItem(
                      value: _StudentAction.open,
                      child: Text('Ver ficha (baja y cuenta)'),
                    ),
                  if (student.dropoutReportedOn == null)
                    const PopupMenuItem(
                      value: _StudentAction.report,
                      child: Text('Avisar que dejó de venir'),
                    )
                  else
                    const PopupMenuItem(
                      value: _StudentAction.cancel,
                      child: Text('Sigue viniendo'),
                    ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _reportDropout(
    GroupAttendance data,
    StudentAttendanceSummary student,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _DropoutDialog(name: student.fullName),
    );
    if (note == null || !mounted) return;
    await _run(
      () => ref
          .read(attendanceRepositoryProvider)
          .reportDropout(data.group.id, student.id, note: note),
      'Listo: le avisamos al club.',
    );
  }

  Future<void> _cancelDropout(
    GroupAttendance data,
    StudentAttendanceSummary student,
  ) => _run(
    () => ref
        .read(attendanceRepositoryProvider)
        .cancelDropout(data.group.id, student.id),
    'Listo: sacamos el aviso.',
  );

  Future<void> _run(Future<Object?> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(groupAttendanceProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }
}

/// Aviso del técnico: nota opcional. Devuelve la nota ('' sin nota) o null si se cancela.
class _DropoutDialog extends StatefulWidget {
  const _DropoutDialog({required this.name});

  final String name;

  @override
  State<_DropoutDialog> createState() => _DropoutDialogState();
}

class _DropoutDialogState extends State<_DropoutDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Dejó de venir?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Le avisamos al club que ${widget.name} dejó de venir. '
          'La baja la decide el club.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Ej.: se mudó, no viene hace 3 semanas',
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
        onPressed: () => Navigator.pop(context, _note.text),
        child: const Text('Avisar'),
      ),
    ],
  );
}
