import 'package:flutter/material.dart';

import '../../attendance/data/models.dart';
import '../../attendance/presentation/attendance_status_style.dart';
import '../../lessons/data/models.dart';
import '../data/models.dart';
import 'calendar_style.dart';

/// Una fila del día: ícono en círculo, título, hora y lugar, y el estado.
class CalendarEntryTile extends StatelessWidget {
  const CalendarEntryTile({
    required this.entry,
    required this.day,
    required this.today,
    required this.now,
    required this.onTap,
    super.key,
  });

  final CalendarEntry entry;

  /// Día de la lista (para "Día 2 de 3" en los eventos largos).
  final DateTime day;
  final DateTime today;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (
      IconData icon,
      Color color,
      String title,
      String subtitle,
      bool struck,
      List<Widget> status,
    ) = switch (entry) {
      ClassEntry(:final item) => (
        Icons.groups_outlined,
        item.session.isOff ? scheme.onSurfaceVariant : scheme.primary,
        _classTitle(item),
        item.session.timeDescription,
        item.session.isOff,
        _classStatus(context, item),
      ),
      BookingEntry(:final item) => (
        Icons.person_outline,
        scheme.onSurfaceVariant,
        item.asTeacher
            ? 'Particular con ${item.booking.student.fullName}'
            : 'Clase particular con ${item.booking.teacher.name}',
        '${item.booking.startsAt}–${item.booking.endsAt}',
        item.booking.status.isCancelled,
        [
          if (item.booking.status != BookingStatus.confirmed)
            StatusChip(
              label: item.booking.status.label,
              icon: Icons.info_outline,
            ),
        ],
      ),
      EventEntry(:final event) => (
        eventIcon(event),
        event.cancelled ? scheme.onSurfaceVariant : scheme.tertiary,
        event.title,
        [
          event.timeDescription,
          ?event.placeName,
          if (event.isMultiDay) 'Día ${event.dayNumber(day)} de ${event.days}',
        ].join(' · '),
        event.cancelled,
        [
          if (event.cancelled)
            StatusChip(
              label: 'Cancelado',
              icon: Icons.cancel_outlined,
              color: scheme.error,
            )
          // El tipo, si el título no lo dice ya ("Reunión de padres").
          else if (!event.title.toLowerCase().contains(
            event.categoryLabel.toLowerCase(),
          ))
            StatusChip(
              label: event.categoryLabel,
              icon: eventIcon(event),
              color: scheme.tertiary,
            ),
        ],
      ),
    };

    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: struck ? TextDecoration.lineThrough : null,
                      color: struck ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 12, runSpacing: 4, children: status),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  static String _classTitle(CalendarClass item) {
    final group = item.session.group;
    final title = '${group.program.name} · ${group.name}';
    return item.students.isEmpty ? title : '$title — ${item.studentNames}';
  }

  List<Widget> _classStatus(BuildContext context, CalendarClass item) {
    final scheme = Theme.of(context).colorScheme;
    final session = item.session;
    if (session.suspended) {
      final reason = session.suspensionReason;
      return [
        StatusChip(
          label: reason == null ? 'Suspendida' : 'Suspendida: $reason',
          icon: Icons.block,
          color: scheme.error,
        ),
      ];
    }
    if (session.rescheduled) {
      final to = session.rescheduledTo;
      return [
        StatusChip(
          label: to == null ? 'Reprogramada' : 'Pasó al ${to.describe(today)}',
          icon: Icons.event_repeat,
        ),
      ];
    }
    return [
      if (session.isMakeup)
        StatusChip(
          label: 'Recuperación',
          icon: Icons.event_repeat,
          color: scheme.primary,
        ),
      for (final student in item.students)
        _StudentStatus(
          student: student,
          showName: item.students.length > 1,
          started: session.hasStarted(now),
        ),
      if (item.students.isEmpty && session.attendanceTaken)
        StatusChip(
          label: 'Asistencia tomada',
          icon: Icons.check_circle_outline,
          color: scheme.primary,
        ),
    ];
  }
}

/// La asistencia de un hijo o, antes de la clase, su respuesta.
class _StudentStatus extends StatelessWidget {
  const _StudentStatus({
    required this.student,
    required this.showName,
    required this.started,
  });

  final CalendarStudent student;
  final bool showName;
  final bool started;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prefix = showName ? '${student.firstName}: ' : '';
    final attendance = student.attendance;
    if (attendance != null) {
      return StatusChip(
        label: '$prefix${attendance.label}',
        icon: attendance.icon,
        color: attendance.color(scheme),
      );
    }
    return switch (student.response) {
      GuardianResponse.going => StatusChip(
        label: '${prefix}Va',
        icon: Icons.check_circle,
        color: scheme.primary,
      ),
      GuardianResponse.notGoing => StatusChip(
        label: '${prefix}No va',
        icon: Icons.event_busy,
      ),
      null when student.canRespond && !started => StatusChip(
        label: '$prefix¿Lo llevás?',
        icon: Icons.help_outline,
        color: scheme.tertiary,
      ),
      null => const SizedBox.shrink(),
    };
  }
}

/// Aviso arriba del día: "Sin clases: Vacaciones de invierno".
class DayOffBanner extends StatelessWidget {
  const DayOffBanner({required this.event, required this.onTap, super.key});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [
      if (event.isMultiDay) event.dateDescription,
      'Para: ${event.audienceDescription}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin clases: ${event.title}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
