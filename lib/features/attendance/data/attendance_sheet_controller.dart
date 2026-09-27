import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'attendance_repository.dart';
import 'models.dart';

/// Nota que se pone sola cuando el tutor avisó que el alumno no va.
const notGoingNote = 'Avisó que no va';

/// Planilla de asistencia de una clase mientras el técnico la completa.
class AttendanceSheet {
  const AttendanceSheet({
    required this.session,
    required this.marks,
    this.notes = const {},
    this.dirty = false,
    this.touched = false,
    this.saving = false,
    this.saveError,
  });

  final ClassSession session;
  final Map<int, AttendanceStatus> marks;
  final Map<int, String> notes;

  /// Hay cambios sin guardar (o la asistencia todavía no se tomó).
  final bool dirty;

  /// El técnico cambió algo desde que abrió o guardó.
  final bool touched;
  final bool saving;

  /// Mensaje del último guardado fallido; las marcas se conservan.
  final String? saveError;

  AttendanceStatus statusOf(int studentId) =>
      marks[studentId] ?? AttendanceStatus.present;

  int count(AttendanceStatus status) =>
      marks.values.where((s) => s == status).length;

  bool get canEdit => session.editable && !session.suspended;

  /// Hay marcas para mostrar: se puede tomar o ya se tomó.
  bool get showsMarks =>
      !session.suspended && (canEdit || session.attendanceTaken);

  AttendanceSheet copyWith({
    ClassSession? session,
    Map<int, AttendanceStatus>? marks,
    Map<int, String>? notes,
    bool? dirty,
    bool? touched,
    bool? saving,
    String? Function()? saveError,
  }) => AttendanceSheet(
    session: session ?? this.session,
    marks: marks ?? this.marks,
    notes: notes ?? this.notes,
    dirty: dirty ?? this.dirty,
    touched: touched ?? this.touched,
    saving: saving ?? this.saving,
    saveError: saveError == null ? this.saveError : saveError(),
  );

  /// Arranca con lo guardado; si no se tomó, todos presentes salvo los que
  /// el tutor avisó que no van (justificados).
  factory AttendanceSheet.from(ClassSession session) {
    final marks = <int, AttendanceStatus>{};
    final notes = <int, String>{};
    for (final student in session.students) {
      if (student.status != null) {
        marks[student.id] = student.status!;
      } else if (student.guardianResponse == GuardianResponse.notGoing) {
        marks[student.id] = AttendanceStatus.justified;
        notes[student.id] = notGoingNote;
      } else {
        marks[student.id] = AttendanceStatus.present;
      }
      if (student.note != null) notes[student.id] = student.note!;
    }
    return AttendanceSheet(
      session: session,
      marks: marks,
      notes: notes,
      dirty: !session.attendanceTaken,
    );
  }
}

class AttendanceSheetController extends AsyncNotifier<AttendanceSheet> {
  AttendanceSheetController(this.classId);

  final int classId;

  AttendanceRepository get _repository =>
      ref.read(attendanceRepositoryProvider);

  @override
  Future<AttendanceSheet> build() async =>
      AttendanceSheet.from(await _repository.find(classId));

  AttendanceSheet? get _sheet => state.value;

  /// Un toque: presente ↔ ausente (un justificado vuelve a presente).
  void toggle(int studentId) {
    final sheet = _sheet;
    if (sheet == null || !sheet.canEdit) return;
    final next = sheet.statusOf(studentId) == AttendanceStatus.present
        ? AttendanceStatus.absent
        : AttendanceStatus.present;
    setStatus(studentId, next);
  }

  void setStatus(int studentId, AttendanceStatus status, {String? note}) {
    final sheet = _sheet;
    if (sheet == null || !sheet.canEdit) return;
    final notes = Map.of(sheet.notes);
    if (status == AttendanceStatus.justified) {
      if (note != null && note.trim().isNotEmpty) {
        notes[studentId] = note.trim();
      }
    } else {
      notes.remove(studentId);
    }
    state = AsyncData(
      sheet.copyWith(
        marks: {...sheet.marks, studentId: status},
        notes: notes,
        dirty: true,
        touched: true,
      ),
    );
  }

  /// Guarda todas las marcas. Si falla, el borrador queda para reintentar.
  Future<bool> save() async {
    final sheet = _sheet;
    if (sheet == null || sheet.saving) return false;
    state = AsyncData(sheet.copyWith(saving: true, saveError: () => null));
    try {
      final saved = await _repository.saveAttendance(
        classId,
        sheet.marks,
        notes: sheet.notes,
      );
      state = AsyncData(AttendanceSheet.from(saved).copyWith(dirty: false));
      return true;
    } catch (error) {
      state = AsyncData(
        sheet.copyWith(saving: false, saveError: () => apiErrorMessage(error)),
      );
      return false;
    }
  }

  Future<void> suspend(String reason) =>
      _replaceSession(() => _repository.suspend(classId, reason));

  Future<void> resume() => _replaceSession(() => _repository.resume(classId));

  Future<void> _replaceSession(Future<ClassSession> Function() call) async {
    final sheet = _sheet;
    if (sheet == null) return;
    final session = await call();
    // Conserva lo que el técnico ya marcó y el detalle de alumnos.
    state = AsyncData(
      sheet.copyWith(
        session: ClassSession(
          id: session.id,
          date: session.date,
          startsAt: session.startsAt,
          endsAt: session.endsAt,
          venue: session.venue,
          group: session.group,
          suspended: session.suspended,
          suspensionReason: session.suspensionReason,
          attendanceTaken: session.attendanceTaken,
          counts: session.counts,
          editable: session.editable,
          students: session.students.isEmpty
              ? sheet.session.students
              : session.students,
        ),
      ),
    );
  }
}

final attendanceSheetProvider = AsyncNotifierProvider.autoDispose
    .family<AttendanceSheetController, AttendanceSheet, int>(
      AttendanceSheetController.new,
      retry: (_, _) => null,
    );
