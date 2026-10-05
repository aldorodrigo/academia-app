import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../attendance/data/guardian_actions.dart';
import '../../attendance/data/models.dart';
import '../../attendance/presentation/attendance_status_style.dart';
import '../data/models.dart';

/// Detalle de una clase para el tutor, con "¿Lo llevás?" por cada hijo.
Future<void> showClassEntrySheet(BuildContext context, CalendarClass item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ClassEntrySheet(item),
    );

class ClassEntrySheet extends ConsumerStatefulWidget {
  const ClassEntrySheet(this.item, {super.key});

  final CalendarClass item;

  @override
  ConsumerState<ClassEntrySheet> createState() => _ClassEntrySheetState();
}

class _ClassEntrySheetState extends ConsumerState<ClassEntrySheet> {
  late var _students = widget.item.students;
  int? _busy;

  Future<void> _respond(CalendarStudent student, bool going) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = student.id);
    try {
      await ref
          .read(guardianActionsProvider)
          .respond(widget.item.session.id, student.id, going: going);
      final response = going
          ? GuardianResponse.going
          : GuardianResponse.notGoing;
      if (!mounted) return;
      setState(() {
        _students = [
          for (final s in _students)
            s.id == student.id ? s.withResponse(response) : s,
        ];
      });
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = widget.item.session;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowProvider);
    final started = session.hasStarted(now);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${session.group.program.name} · ${session.group.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${formatShortDay(session.date, today)} · ${session.timeDescription}',
              style: theme.textTheme.bodyMedium,
            ),
            if (session.isMakeup && session.rescheduledFrom != null) ...[
              const SizedBox(height: 8),
              _Line(
                icon: Icons.event_repeat,
                text:
                    'Recupera la clase '
                    '${session.rescheduledFrom!.describeAfterClass(today)}.',
              ),
            ],
            if (session.suspended) ...[
              const SizedBox(height: 8),
              _Line(
                icon: Icons.block,
                color: scheme.error,
                text: session.suspensionReason == null
                    ? 'Clase suspendida.'
                    : 'Clase suspendida: ${session.suspensionReason}.',
              ),
            ],
            if (session.rescheduled && session.rescheduledTo != null) ...[
              const SizedBox(height: 8),
              _Line(
                icon: Icons.event_repeat,
                text:
                    'Se pasó al ${session.rescheduledTo!.describe(today).toLowerCase()}.',
              ),
            ],
            const Divider(height: 32),
            for (final student in _students)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StudentRow(
                  student: student,
                  canRespond: student.canRespond && !started && !session.isOff,
                  busy: _busy == student.id,
                  onRespond: (going) => _respond(student, going),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.canRespond,
    required this.busy,
    required this.onRespond,
  });

  final CalendarStudent student;
  final bool canRespond;
  final bool busy;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = Text(student.firstName, style: theme.textTheme.titleMedium);
    if (student.attendance != null) {
      return Row(
        children: [
          Expanded(child: name),
          AttendanceStatusLabel(student.attendance),
        ],
      );
    }
    if (!canRespond) {
      return Row(
        children: [
          Expanded(child: name),
          Text(switch (student.response) {
            GuardianResponse.going => 'Avisaste que va',
            GuardianResponse.notGoing => 'Avisaste que no va',
            null => 'Sin respuesta',
          }),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: name),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: false, label: Text('No va')),
            ButtonSegment(value: true, label: Text('Sí, va')),
          ],
          selected: {
            if (student.response != null)
              student.response == GuardianResponse.going,
          },
          onSelectionChanged: busy
              ? null
              : (selection) {
                  if (selection.isNotEmpty) onRespond(selection.single);
                },
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}
