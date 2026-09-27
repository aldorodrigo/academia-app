import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../students/data/models.dart';
import '../data/attendance_repository.dart';
import '../data/guardian_actions.dart';
import 'attendance_status_style.dart';

/// Sección "Asistencia" de la ficha: % del mes, últimas clases y el aviso de
/// los días de clase.
class StudentAttendanceSection extends ConsumerStatefulWidget {
  const StudentAttendanceSection({super.key, required this.student});

  final Student student;

  @override
  ConsumerState<StudentAttendanceSection> createState() =>
      _StudentAttendanceSectionState();
}

class _StudentAttendanceSectionState
    extends ConsumerState<StudentAttendanceSection> {
  static const _lastClasses = 5;

  bool? _reminders;
  bool _busy = false;

  Future<void> _setReminders(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _reminders = enabled;
    });
    try {
      final result = await ref
          .read(guardianActionsProvider)
          .setReminders(widget.student.id, enabled: enabled);
      messenger.showSnackBar(
        SnackBar(
          content: Text(remindersMessage(result, widget.student.firstName)),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _reminders = !enabled);
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final attendance = ref.watch(
      studentAttendanceProvider((
        studentId: widget.student.id,
        month: DateTime(today.year, today.month),
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avisarme los días de clase'),
          subtitle: const Text('Unas horas antes, para confirmar si va.'),
          value: _reminders ?? widget.student.classReminders ?? false,
          onChanged: _busy ? null : _setReminders,
        ),
        attendance.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(apiErrorMessage(error)),
          data: (attendance) {
            final classes = attendance.classes.take(_lastClasses);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  attendance.rate == null
                      ? '${formatPeriod(attendance.month)}: todavía sin clases tomadas.'
                      : '${formatPeriod(attendance.month)}: vino al '
                            '${attendance.rate}% de las clases '
                            '(${_plural(attendance.present, 'presente')}, '
                            '${_plural(attendance.absent, 'ausente')}, '
                            '${_plural(attendance.justified, 'justificado')}).',
                  style: theme.textTheme.bodyMedium,
                ),
                for (final entry in classes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${formatDate(entry.session.date)} · '
                      '${entry.session.group.program.name} ${entry.session.startsAt}',
                    ),
                    trailing: entry.session.isOff
                        ? Text(
                            entry.session.rescheduled
                                ? 'Reprogramada'
                                : 'Suspendida',
                          )
                        : AttendanceStatusLabel(entry.status),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _plural(int count, String word) =>
    '$count ${count == 1 ? word : '${word}s'}';
