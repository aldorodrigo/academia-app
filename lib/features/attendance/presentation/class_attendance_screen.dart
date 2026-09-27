import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_sheet_controller.dart';
import '../data/models.dart';
import 'attendance_status_style.dart';
import 'class_change_dialogs.dart';

/// Tomar asistencia: todos arrancan presentes y un toque marca ausente.
class ClassAttendanceScreen extends ConsumerStatefulWidget {
  const ClassAttendanceScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ClassAttendanceScreen> createState() =>
      _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends ConsumerState<ClassAttendanceScreen> {
  static const _searchFrom = 20;

  String _query = '';

  AttendanceSheetController get _controller =>
      ref.read(attendanceSheetProvider(widget.id).notifier);

  Future<void> _leave(AttendanceSheet? sheet) async {
    if (sheet != null && sheet.touched && sheet.dirty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Salir sin guardar?'),
          content: const Text('Los cambios de la asistencia se van a perder.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir marcando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    if (mounted) context.go('/inicio');
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!mounted || !saved) return;
    ref.invalidate(classesProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Asistencia guardada.')));
  }

  Future<void> _justify(ClassStudent student, AttendanceSheet sheet) async {
    final result = await showModalBottomSheet<(AttendanceStatus, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MarkSheet(
        student: student,
        status: sheet.statusOf(student.id),
        note: sheet.notes[student.id],
      ),
    );
    if (result == null) return;
    _controller.setStatus(student.id, result.$1, note: result.$2);
  }

  Future<void> _suspend(ClassSession session) async {
    final choice = await showDialog<SuspendChoice>(
      context: context,
      builder: (_) => SuspendDialog(canWaiveCharge: session.canWaiveCharge),
    );
    if (choice == null || !mounted) return;
    if (choice.reschedule) {
      await _reschedule(session, reason: choice.reason);
      return;
    }
    await _run(
      () => _controller.suspend(choice.reason, waiveCharge: choice.waiveCharge),
      'Clase suspendida. Se avisó a los tutores.',
    );
  }

  Future<void> _reschedule(ClassSession session, {String? reason}) async {
    final request = await showModalBottomSheet<RescheduleRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RescheduleSheet(session: session, reason: reason),
    );
    if (request == null) return;
    await _run(
      () => _controller.reschedule(request),
      'Clase reprogramada. Se avisó a los tutores.',
    );
  }

  void _onMenu(String action, ClassSession session) {
    switch (action) {
      case 'suspend':
        _suspend(session);
      case 'move':
        _reschedule(session);
      case 'reschedule':
        _reschedule(session, reason: session.suspensionReason);
      case 'resume':
        _run(_controller.resume, 'La clase vuelve a estar programada.');
      case 'cancel_reschedule':
        _run(
          _controller.cancelReschedule,
          'Se canceló la reprogramación. Se avisó a los tutores.',
        );
      case 'open_makeup':
        context.go('/clases/${session.rescheduledTo!.id}');
      case 'open_original':
        context.go('/clases/${session.rescheduledFrom!.id}');
    }
  }

  /// Opciones del menú según el estado de la clase.
  List<PopupMenuEntry<String>> _menu(ClassSession session) {
    final today = ref.read(todayProvider);
    final now = ref.read(nowProvider);
    final past = session.isPast(today);
    PopupMenuItem<String> item(String value, String text) =>
        PopupMenuItem(value: value, child: Text(text));

    return [
      if (session.rescheduled) ...[
        if (session.rescheduledTo != null)
          item('open_makeup', 'Ver la recuperación'),
        if (session.rescheduledTo != null &&
            !DateTime(
              session.rescheduledTo!.date.year,
              session.rescheduledTo!.date.month,
              session.rescheduledTo!.date.day,
            ).isBefore(today))
          item('cancel_reschedule', 'Cancelar reprogramación'),
      ] else if (session.suspended) ...[
        if (!past) item('resume', 'Volver a programar'),
        if (!past) item('reschedule', 'Reprogramar'),
      ] else if (!past) ...[
        item('suspend', 'Suspender clase'),
        if (!session.hasStarted(now)) item('move', 'Cambiar día u horario'),
      ],
      if (session.isMakeup && session.rescheduledFrom != null)
        item('open_original', 'Ver la clase original'),
    ];
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(classesProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(attendanceSheetProvider(widget.id));
    final sheet = value.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(sheet);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(sheet?.session.group.name ?? 'Asistencia'),
          leading: BackButton(onPressed: () => _leave(sheet)),
          actions: [
            if (sheet != null && _menu(sheet.session).isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (action) => _onMenu(action, sheet.session),
                itemBuilder: (_) => _menu(sheet.session),
              ),
          ],
        ),
        body: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
            ),
          ),
          data: _body,
        ),
        bottomNavigationBar: sheet == null || !sheet.canEdit
            ? null
            : _SaveBar(sheet: sheet, onSave: _save),
      ),
    );
  }

  Widget _body(AttendanceSheet sheet) {
    final session = sheet.session;
    final query = _query.trim().toLowerCase();
    final students = query.isEmpty
        ? session.students
        : session.students
              .where((s) => s.fullName.toLowerCase().contains(query))
              .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Header(sheet),
        if (session.students.length > _searchFrom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar',
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        if (session.students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay alumnos inscriptos en esta clase.'),
          ),
        for (final student in students)
          _StudentRow(
            student: student,
            status: sheet.showsMarks ? sheet.statusOf(student.id) : null,
            note: sheet.notes[student.id],
            enabled: sheet.canEdit,
            onTap: () => _controller.toggle(student.id),
            onMore: () => _justify(student, sheet),
          ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header(this.sheet);

  final AttendanceSheet sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = sheet.session;
    final today = ref.watch(todayProvider);
    final day = formatShortDay(session.date, today);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${session.group.program.name} · '
            '$day ${session.timeDescription}',
            style: theme.textTheme.titleSmall,
          ),
          if (session.isMakeup && session.rescheduledFrom != null) ...[
            const SizedBox(height: 8),
            _Banner(
              icon: Icons.event_repeat,
              text:
                  'Recuperación de la clase '
                  '${session.rescheduledFrom!.describeAfterClass(today)}.',
            ),
          ],
          if (session.rescheduled) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.event_repeat,
              text: [
                session.rescheduledTo == null
                    ? 'Clase reprogramada.'
                    : 'Reprogramada: ${session.rescheduledTo!.describe(today)}.',
                if (session.suspensionReason != null)
                  'Motivo: ${session.suspensionReason}.',
              ].join(' '),
            ),
          ] else if (session.suspended) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.block,
              text: [
                session.suspensionReason == null
                    ? 'Clase suspendida.'
                    : 'Clase suspendida: ${session.suspensionReason}.',
                if (session.chargeWaived) 'No se cobra.',
              ].join(' '),
            ),
          ] else if (!session.editable) ...[
            const SizedBox(height: 12),
            session.date.isAfter(today)
                ? const _Banner(
                    icon: Icons.schedule,
                    text:
                        'La asistencia se toma el día de la clase. '
                        'Mientras tanto ves quiénes avisaron que van.',
                  )
                : const _Banner(
                    icon: Icons.lock_outline,
                    text: 'Ya no se puede corregir desde la app.',
                  ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Tocá a los que faltaron. Para justificar, usá ⋮.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (sheet.showsMarks) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in AttendanceStatus.values)
                  _CountChip(status, sheet.count(status)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.status, this.count);

  final AttendanceStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = status.color(Theme.of(context).colorScheme);
    final label = switch (status) {
      AttendanceStatus.present => count == 1 ? 'presente' : 'presentes',
      AttendanceStatus.absent => count == 1 ? 'ausente' : 'ausentes',
      AttendanceStatus.justified => count == 1 ? 'justificado' : 'justificados',
    };
    return Chip(
      avatar: Icon(status.icon, color: color, size: 18),
      label: Text('$count $label'),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.status,
    required this.note,
    required this.enabled,
    required this.onTap,
    required this.onMore,
  });

  final ClassStudent student;
  final AttendanceStatus? status;
  final String? note;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onMore;

  String? get _subtitle {
    final response = switch (student.guardianResponse) {
      GuardianResponse.going => 'El tutor avisó que va',
      GuardianResponse.notGoing => notGoingNote,
      null => null,
    };
    if (note != null && note != response) {
      return response == null ? note : '$response · $note';
    }
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = student.photoUrl;
    final subtitle = _subtitle;

    return Semantics(
      label: '${student.fullName}: ${status?.label ?? 'sin tomar'}',
      child: ListTile(
        minTileHeight: 64,
        enabled: enabled,
        leading: CircleAvatar(
          foregroundImage: photo == null ? null : NetworkImage(photo),
          child: Text(student.initials),
        ),
        title: Text(student.fullName),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AttendanceStatusLabel(status),
            IconButton(
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_vert),
              color: scheme.onSurfaceVariant,
              onPressed: enabled ? onMore : null,
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: onMore,
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.sheet, required this.onSave});

  final AttendanceSheet sheet;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final error = sheet.saveError;
    final present = sheet.count(AttendanceStatus.present);
    final total = sheet.session.students.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No se pudo guardar: $error Tus marcas no se perdieron.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: sheet.saving || !sheet.dirty ? null : onSave,
              child: sheet.saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      error != null
                          ? 'Reintentar'
                          : !sheet.dirty
                          ? 'Asistencia guardada'
                          : 'Guardar asistencia ($present de $total)',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elegir la marca de un alumno, con nota opcional para justificar.
class _MarkSheet extends StatefulWidget {
  const _MarkSheet({required this.student, required this.status, this.note});

  final ClassStudent student;
  final AttendanceStatus status;
  final String? note;

  @override
  State<_MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<_MarkSheet> {
  late var _status = widget.status;
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.student.fullName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RadioGroup<AttendanceStatus>(
            groupValue: _status,
            onChanged: (value) => setState(() => _status = value!),
            child: Column(
              children: [
                for (final status in AttendanceStatus.values)
                  RadioListTile<AttendanceStatus>(
                    value: status,
                    title: Text(status.label),
                    secondary: Icon(status.icon, color: status.color(scheme)),
                  ),
              ],
            ),
          ),
          if (_status == AttendanceStatus.justified) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej.: enfermo, viaje',
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, (_status, _note.text)),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
