import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/offline_store.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

/// Nuevo día y horario de una clase.
class RescheduleRequest {
  const RescheduleRequest({
    required this.date,
    required this.startsAt,
    required this.endsAt,
    this.venueId,
    this.reason,
  });

  final DateTime date;

  /// "09:00".
  final String startsAt;
  final String endsAt;
  final int? venueId;
  final String? reason;

  Map<String, Object?> toJson() => {
    'date': apiDate(date),
    'starts_at': startsAt,
    'ends_at': endsAt,
    'venue_id': ?venueId,
    'reason': ?reason,
  };
}

class AttendanceRepository {
  AttendanceRepository(this._dio, this._storage, {this._cache});

  final Dio _dio;
  final SessionStorage _storage;

  /// Copia de las clases para abrirlas sin conexión (null = sin caché).
  final OfflineStore? _cache;

  /// Clases del día de los grupos del técnico (sin conexión, las guardadas).
  Future<List<ClassSession>> classes(DateTime date) async {
    final body = await _getCached(
      '/classes',
      'classes:${apiDate(date)}',
      queryParameters: {'date': apiDate(date)},
    );
    return _items(body, ClassSession.fromJson);
  }

  /// Clase con sus alumnos, para tomar asistencia (sin conexión, la guardada).
  Future<ClassSession> find(int id) async {
    final body = await _getCached('/classes/$id', 'class:$id');
    return ClassSession.fromJson(_data(body));
  }

  /// Guarda en el celular el detalle de las clases (para abrirlas sin señal).
  Future<void> precache(List<ClassSession> classes) async {
    if (_cache == null) return;
    for (final session in classes) {
      try {
        await find(session.id);
      } catch (_) {
        // Sin conexión o error: se queda con lo que ya tenía.
      }
    }
  }

  /// GET que guarda la respuesta y, si no hay red, devuelve la última guardada.
  Future<Map<String, dynamic>> _getCached(
    String path,
    String key, {
    Map<String, Object?>? queryParameters,
  }) async {
    final cache = _cache;
    final cacheKey = '${await _storage.readOrganization() ?? ''}:$key';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      await _safely(() => cache?.write(cacheKey, jsonEncode(response.data)));
      return response.data!;
    } catch (error) {
      if (cache != null && isNetworkError(error)) {
        final cached = await _safely(() => cache.read(cacheKey));
        if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// La caché nunca rompe una consulta: si falla, se sigue sin ella.
  static Future<T?> _safely<T>(Future<T?>? Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Future<ClassSession> saveAttendance(
    int id,
    Map<int, AttendanceStatus> marks, {
    Map<int, String> notes = const {},
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/classes/$id/attendance',
      data: {
        'marks': [
          for (final entry in marks.entries)
            {
              'student_id': entry.key,
              'status': entry.value.value,
              'note': notes[entry.key],
            },
        ],
      },
    );
    return ClassSession.fromJson(_data(response.data!));
  }

  Future<ClassSession> suspend(
    int id,
    String reason, {
    bool waiveCharge = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/classes/$id/suspension',
      data: {'reason': reason, 'waive_charge': waiveCharge},
    );
    return ClassSession.fromJson(_data(response.data!));
  }

  /// Pasa la clase a otro día u horario (crea la recuperación).
  /// La clase y los avisos (si ese día otra categoría usa la cancha a esa hora).
  Future<(ClassSession, List<String>)> reschedule(
    int id,
    RescheduleRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/classes/$id/reschedule',
      data: request.toJson(),
    );
    final warnings = response.data!['warnings'];
    return (
      ClassSession.fromJson(_data(response.data!)),
      warnings is List ? List<String>.from(warnings) : const <String>[],
    );
  }

  Future<ClassSession> cancelReschedule(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/classes/$id/reschedule',
    );
    return ClassSession.fromJson(_data(response.data!));
  }

  Future<List<Venue>> venues() async {
    final response = await _dio.get<Map<String, dynamic>>('/venues');
    return _items(response.data!, Venue.fromJson);
  }

  Future<ClassSession> resume(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/classes/$id/suspension',
    );
    return ClassSession.fromJson(_data(response.data!));
  }

  Future<List<InstructorGroup>> groups() async {
    final response = await _dio.get<Map<String, dynamic>>('/groups');
    return _items(response.data!, InstructorGroup.fromJson);
  }

  Future<GroupAttendance> group(int id, DateTime month) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/groups/$id',
      queryParameters: {'month': apiMonth(month)},
    );
    return GroupAttendance.fromJson(_data(response.data!));
  }

  /// Avisa al club que el alumno dejó de venir (el club decide si le da la baja).
  /// Devuelve la fecha del aviso.
  Future<DateTime> reportDropout(
    int groupId,
    int studentId, {
    String? note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/groups/$groupId/students/$studentId/dropout',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    return DateTime.parse(
      _data(response.data!)['dropout_reported_on'] as String,
    );
  }

  /// Deshace el aviso: el alumno sigue viniendo.
  Future<void> cancelDropout(int groupId, int studentId) async {
    await _dio.delete<void>('/groups/$groupId/students/$studentId/dropout');
  }

  /// Próxima clase de cada alumno a cargo del tutor, por fecha y hora de
  /// inicio (la API ya las manda así; a la misma hora se respeta su orden).
  Future<List<AgendaItem>> agenda() async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>('/agenda');
    final items = _items(response.data!, AgendaItem.fromJson).indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.session.date.compareTo(b.$2.session.date);
        if (byDate != 0) return byDate;
        final byTime = a.$2.session.startsAt.compareTo(b.$2.session.startsAt);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in items) item];
  }

  Future<AgendaItem> respond(
    int classId,
    int studentId, {
    required bool going,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/classes/$classId/students/$studentId/response',
      data: {'going': going},
    );
    return AgendaItem.fromJson(_data(response.data!));
  }

  Future<StudentAttendance> studentAttendance(
    int studentId,
    DateTime month,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/students/$studentId/attendance',
      queryParameters: {'month': apiMonth(month)},
    );
    return StudentAttendance.fromJson(_data(response.data!));
  }

  /// Activa o desactiva el aviso de los días de clase de un alumno.
  Future<bool> setReminders(int studentId, {required bool enabled}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/students/$studentId/reminders',
      data: {'enabled': enabled},
    );
    return _data(response.data!)['class_reminders'] as bool? ?? enabled;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> body) =>
      body['data'] as Map<String, dynamic>;

  static List<T> _items<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) => (body['data'] as List)
      .map((e) => parse(e as Map<String, dynamic>))
      .toList();
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
    cache: ref.watch(offlineStoreProvider),
  ),
);

/// Clases del día; de paso guarda el detalle de cada una para abrirlas sin señal.
final classesProvider = FutureProvider.autoDispose
    .family<List<ClassSession>, DateTime>((ref, date) async {
      final repository = ref.watch(attendanceRepositoryProvider);
      final classes = await repository.classes(date);
      unawaited(repository.precache(classes));
      return classes;
    }, retry: (_, _) => null);

final classProvider = FutureProvider.autoDispose.family<ClassSession, int>(
  (ref, id) => ref.watch(attendanceRepositoryProvider).find(id),
  retry: (_, _) => null,
);

final venuesProvider = FutureProvider.autoDispose<List<Venue>>(
  (ref) => ref.watch(attendanceRepositoryProvider).venues(),
  retry: (_, _) => null,
);

final instructorGroupsProvider =
    FutureProvider.autoDispose<List<InstructorGroup>>(
      (ref) => ref.watch(attendanceRepositoryProvider).groups(),
      retry: (_, _) => null,
    );

/// Grupo en un mes (se pasa cualquier día del mes).
final groupAttendanceProvider = FutureProvider.autoDispose
    .family<GroupAttendance, ({int id, DateTime month})>(
      (ref, key) =>
          ref.watch(attendanceRepositoryProvider).group(key.id, key.month),
      retry: (_, _) => null,
    );

/// Se vuelve a pedir cada vez que cambia la organización elegida.
final agendaProvider = FutureProvider<List<AgendaItem>>((ref) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  return ref.watch(attendanceRepositoryProvider).agenda();
});

final studentAttendanceProvider = FutureProvider.autoDispose
    .family<StudentAttendance, ({int studentId, DateTime month})>(
      (ref, key) => ref
          .watch(attendanceRepositoryProvider)
          .studentAttendance(key.studentId, key.month),
      retry: (_, _) => null,
    );
