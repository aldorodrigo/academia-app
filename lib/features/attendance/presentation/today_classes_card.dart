import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import 'attendance_status_style.dart';

/// Tarjeta del inicio para el técnico: las clases de hoy de sus grupos y el
/// acceso directo a tomar asistencia.
class TodayClassesCard extends ConsumerWidget {
  const TodayClassesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref.watch(currentOrganizationProvider).value?.can('take_attendance') ??
        false;
    if (!allowed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final classes = ref.watch(classesProvider(ref.watch(todayProvider)));

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
                TextButton(
                  onPressed: () => context.go('/grupos'),
                  child: const Text('Mis grupos'),
                ),
              ],
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
                  : Column(children: [for (final c in classes) _ClassRow(c)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow(this.session);

  final ClassSession session;

  String get _summary {
    final counts = session.counts;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = session.group;

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
              if (session.suspended) const SuspendedChip(),
            ],
          ),
          Text(session.timeDescription),
          Text(_summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (!session.suspended && !session.attendanceTaken)
            FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Tomar asistencia'),
              onPressed: () => context.go('/clases/${session.id}'),
            )
          else
            OutlinedButton(
              onPressed: () => context.go('/clases/${session.id}'),
              child: Text(
                session.suspended ? 'Ver clase' : 'Ver o corregir asistencia',
              ),
            ),
        ],
      ),
    );
  }
}
