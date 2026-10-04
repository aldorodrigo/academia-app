import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';
import 'attendance_status_style.dart';

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
                ? '${countOf(session.counts.present, 'presente', 'presentes')} · '
                      '${countOf(session.counts.absent, 'ausente', 'ausentes')} · '
                      '${countOf(session.counts.justified, 'justificado', 'justificados')}'
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
          subtitle: Row(
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
          trailing: Text(
            student.rate == null ? '—' : '${student.rate}%',
            style: theme.textTheme.titleMedium,
          ),
        ),
    ];
  }
}
