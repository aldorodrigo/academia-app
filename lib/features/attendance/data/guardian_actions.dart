import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
import '../../students/data/students_repository.dart';
import 'attendance_repository.dart';

/// Resultado de activar el aviso de los días de clase.
enum RemindersResult {
  /// Guardado y el dispositivo quedó registrado para push.
  enabled,

  /// Guardado, pero no se dio permiso de notificaciones en este celular.
  permissionDenied,

  /// Guardado desde un dispositivo sin push (la web): llega a la app del celular.
  savedWithoutPush,

  disabled,
}

/// Acciones del tutor sobre las clases de sus hijos.
class GuardianActions {
  GuardianActions(this._ref);

  final Ref _ref;

  AttendanceRepository get _repository =>
      _ref.read(attendanceRepositoryProvider);

  /// "¿Lo llevás?": va o no va.
  Future<void> respond(
    int classId,
    int studentId, {
    required bool going,
  }) async {
    await _repository.respond(classId, studentId, going: going);
    _ref.invalidate(agendaProvider);
  }

  /// Guarda la preferencia; al activarla pide permiso de notificaciones.
  Future<RemindersResult> setReminders(
    int studentId, {
    required bool enabled,
  }) async {
    await _repository.setReminders(studentId, enabled: enabled);
    _ref.invalidate(agendaProvider);
    _ref.invalidate(studentProvider(studentId));
    if (!enabled) return RemindersResult.disabled;
    final push = _ref.read(pushServiceProvider);
    if (!push.isSupported) return RemindersResult.savedWithoutPush;
    return await push.enable()
        ? RemindersResult.enabled
        : RemindersResult.permissionDenied;
  }
}

final guardianActionsProvider = Provider<GuardianActions>(GuardianActions.new);

/// Mensaje para mostrar después de cambiar el aviso.
String remindersMessage(RemindersResult result, String firstName) =>
    switch (result) {
      RemindersResult.enabled =>
        'Listo: te avisamos los días de clase de $firstName.',
      RemindersResult.permissionDenied => 'Listo. Para recibir el aviso, permití las notificaciones de la app en tu celular.',
      RemindersResult.savedWithoutPush =>
        'Listo. El aviso te llega en la app instalada en tu celular.',
      RemindersResult.disabled =>
        'No te vamos a avisar los días de clase de $firstName.',
    };
