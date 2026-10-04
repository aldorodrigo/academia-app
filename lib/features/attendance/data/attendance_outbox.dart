import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/offline_store.dart';
import '../../../core/storage/session_storage.dart';
import 'attendance_repository.dart';
import 'models.dart';

/// Asistencia guardada en el celular que todavía no llegó al servidor.
class PendingAttendance {
  const PendingAttendance({
    required this.classId,
    required this.marks,
    this.notes = const {},
    required this.savedAt,
    this.error,
  });

  factory PendingAttendance.fromJson(Map<String, dynamic> json) =>
      PendingAttendance(
        classId: json['class_id'] as int,
        marks: {
          for (final e in (json['marks'] as Map<String, dynamic>).entries)
            int.parse(e.key): AttendanceStatus.parse(e.value)!,
        },
        notes: {
          for (final e
              in ((json['notes'] as Map<String, dynamic>?) ?? {}).entries)
            int.parse(e.key): e.value as String,
        },
        savedAt: DateTime.parse(json['saved_at'] as String),
        error: json['error'] as String?,
      );

  final int classId;
  final Map<int, AttendanceStatus> marks;
  final Map<int, String> notes;
  final DateTime savedAt;

  /// El servidor la rechazó (no se reintenta sola): "Esta clase ya no se puede corregir…".
  final String? error;

  PendingAttendance withError(String? error) => PendingAttendance(
    classId: classId,
    marks: marks,
    notes: notes,
    savedAt: savedAt,
    error: error,
  );

  Map<String, Object?> toJson() => {
    'class_id': classId,
    'marks': {for (final e in marks.entries) '${e.key}': e.value.value},
    'notes': {for (final e in notes.entries) '${e.key}': e.value},
    'saved_at': savedAt.toIso8601String(),
    'error': error,
  };
}

/// Cola de asistencia sin conexión: una entrada por clase (la última gana; el
/// `PUT classes/{id}/attendance` es idempotente). Se guarda en el celular.
class AttendanceOutbox extends AsyncNotifier<Map<int, PendingAttendance>> {
  bool _flushing = false;

  OfflineStore get _store => ref.read(offlineStoreProvider);

  Future<String> _key() async =>
      '${await ref.read(sessionStorageProvider).readOrganization() ?? ''}:outbox';

  @override
  Future<Map<int, PendingAttendance>> build() async {
    final String? raw;
    try {
      raw = await _store.read(await _key());
    } catch (_) {
      return const {}; // Sin almacenamiento (ej. navegador privado): sin cola.
    }
    if (raw == null) return const {};
    return {
      for (final item in jsonDecode(raw) as List)
        (item as Map<String, dynamic>)['class_id'] as int:
            PendingAttendance.fromJson(item),
    };
  }

  Future<void> enqueue(
    int classId,
    Map<int, AttendanceStatus> marks,
    Map<int, String> notes,
  ) async {
    final current = await future;
    await _persist({
      ...current,
      classId: PendingAttendance(
        classId: classId,
        marks: marks,
        notes: notes,
        savedAt: DateTime.now(),
      ),
    });
  }

  Future<void> discard(int classId) async {
    final current = await future;
    await _persist({...current}..remove(classId));
  }

  /// Envía lo pendiente. Sin red, se detiene y queda para después; un rechazo
  /// de la API queda marcado con su mensaje. Devuelve cuántas se enviaron.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final pending = {...await future};
      final repository = ref.read(attendanceRepositoryProvider);
      for (final item in pending.values.toList()) {
        if (item.error != null) continue;
        try {
          await repository.saveAttendance(
            item.classId,
            item.marks,
            notes: item.notes,
          );
          pending.remove(item.classId);
          sent++;
          ref.invalidate(classProvider(item.classId));
        } catch (error) {
          if (isNetworkError(error)) break;
          pending[item.classId] = item.withError(apiErrorMessage(error));
        }
      }
      await _persist(pending);
      if (sent > 0) ref.invalidate(classesProvider);
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<void> _persist(Map<int, PendingAttendance> items) async {
    state = AsyncData(Map.unmodifiable(items));
    await _store.write(
      await _key(),
      items.isEmpty
          ? null
          : jsonEncode([for (final item in items.values) item.toJson()]),
    );
  }
}

final attendanceOutboxProvider =
    AsyncNotifierProvider<AttendanceOutbox, Map<int, PendingAttendance>>(
      AttendanceOutbox.new,
    );
