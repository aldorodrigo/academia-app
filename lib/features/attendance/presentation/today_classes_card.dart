import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/offline_store.dart';
import '../../../core/utils/clock.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/attendance_outbox.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import 'attendance_status_style.dart';

/// Tarjeta del inicio para el técnico: las clases de hoy de sus grupos y el
/// acceso directo a tomar asistencia.
class TodayClassesCard extends ConsumerWidget {
  const TodayClassesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider).value;
    if (!(organization?.can('take_attendance') ?? false)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final classes = ref.watch(classesProvider(ref.watch(todayProvider)));
    final pending = ref.watch(attendanceOutboxProvider).value ?? const {};
    final online = ref.watch(connectivityProvider).value ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_soccer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Hoy', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Configurar avisos',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notificaciones'),
                ),
                TextButton(
                  onPressed: () => context.go('/grupos'),
                  child: Text('Mis ${organization!.word('group').pluralLower}'),
                ),
              ],
            ),
            if (!online)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión: ves lo guardado en el celular.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            classes.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (classes) => classes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Hoy no tenés clases.'),
                    )
                  : Column(
                      children: [
                        for (final c in classes) _ClassRow(c, pending[c.id]),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow(this.session, this.pending);

  final ClassSession session;

  /// Asistencia guardada sin conexión que todavía no se envió.
  final PendingAttendance? pending;

  String _summary(DateTime today) {
    final counts = session.counts;
    if (session.rescheduled) {
      final to = session.rescheduledTo;
      return to == null
          ? 'Reprogramada'
          : 'Reprogramada: ${to.describe(today)}';
    }
    if (session.suspended) {
      return session.suspensionReason == null
          ? 'Suspendida'
          : 'Suspendida: ${session.suspensionReason}';
    }
    if (session.attendanceTaken) {
      return [
        'Tomada: ${counts.present} ${counts.present == 1 ? 'presente' : 'presentes'}',
        if (counts.absent > 0)
          '${counts.absent} ${counts.absent == 1 ? 'ausente' : 'ausentes'}',
        if (counts.justified > 0)
          '${counts.justified} ${counts.justified == 1 ? 'justificado' : 'justificados'}',
      ].join(' · ');
    }
    return [
      '${counts.going} van',
      if (counts.notGoing > 0) '${counts.notGoing} no van',
      if (counts.noAnswer > 0) '${counts.noAnswer} sin responder',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final group = session.group;
    final today = ref.watch(todayProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.name} · ${group.program.name}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (session.isMakeup)
                const Chip(
                  avatar: Icon(Icons.event_repeat, size: 18),
                  label: Text('Recuperación'),
                  visualDensity: VisualDensity.compact,
                ),
              if (session.suspended) const SuspendedChip(),
            ],
          ),
          Text(session.timeDescription),
          Text(_summary(today), style: theme.textTheme.bodySmall),
          if (pending != null)
            Row(
              children: [
                Icon(
                  pending!.error == null
                      ? Icons.cloud_off_outlined
                      : Icons.error_outline,
                  size: 16,
                  color: pending!.error == null
                      ? null
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pending!.error == null
                        ? 'Asistencia guardada en el celular, falta enviarla'
                        : 'No se pudo enviar la asistencia',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (!session.isOff && !session.attendanceTaken && pending == null)
            FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Tomar asistencia'),
              onPressed: () => context.go('/clases/${session.id}'),
            )
          else
            OutlinedButton(
              onPressed: () => context.go('/clases/${session.id}'),
              child: Text(
                session.isOff ? 'Ver clase' : 'Ver o corregir asistencia',
              ),
            ),
        ],
      ),
    );
  }
}
