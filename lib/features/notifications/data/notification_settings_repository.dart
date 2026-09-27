import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/session_storage.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/guardian_actions.dart';
import 'models.dart';

class NotificationSettingsRepository {
  NotificationSettingsRepository(this._dio, this._storage);

  final Dio _dio;

  // Mismo contrato que el resto de los repositorios (sesión y organización por el interceptor).
  // ignore: unused_field
  final SessionStorage _storage;

  Future<NotificationSettings> get() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/notification-settings',
    );
    return NotificationSettings.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<NotificationSettings> save({
    InstructorReminders? instructor,
    GuardianReminders? guardian,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/me/notification-settings',
      data: {
        if (instructor != null) 'instructor': instructor.toJson(),
        if (guardian != null) 'guardian': guardian.toJson(),
      },
    );
    return NotificationSettings.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }
}

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>(
      (ref) => NotificationSettingsRepository(
        ref.watch(apiClientProvider),
        ref.watch(sessionStorageProvider),
      ),
    );

/// Avisos del usuario; cada cambio se guarda enseguida (y vuelve atrás si falla).
class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings> {
  NotificationSettingsRepository get _repository =>
      ref.read(notificationSettingsRepositoryProvider);

  @override
  Future<NotificationSettings> build() => _repository.get();

  Future<void> setInstructorEnabled(bool enabled) async {
    final current = state.value?.instructor;
    if (current == null) return;
    await _save(instructor: current.copyWith(enabled: enabled));
    if (enabled) await ref.read(pushServiceProvider).enable();
  }

  Future<void> addOffset(ReminderOffset offset, {required bool instructor}) =>
      _change(instructor, (offsets) => ({...offsets, offset}.toList()..sort()));

  Future<void> removeOffset(
    ReminderOffset offset, {
    required bool instructor,
  }) => _change(
    instructor,
    (offsets) => offsets.where((o) => o != offset).toList(),
  );

  /// Aviso por hijo: el mismo interruptor que en la ficha.
  Future<RemindersResult> setChild(
    int studentId, {
    required bool enabled,
  }) async {
    final result = await ref
        .read(guardianActionsProvider)
        .setReminders(studentId, enabled: enabled);
    state = AsyncData(await _repository.get());
    return result;
  }

  Future<void> _change(
    bool instructor,
    List<ReminderOffset> Function(List<ReminderOffset>) update,
  ) async {
    final settings = state.value;
    if (settings == null) return;
    if (instructor) {
      final current = settings.instructor;
      if (current == null) return;
      await _save(
        instructor: current.copyWith(offsets: update(current.offsets)),
      );
    } else {
      final current = settings.guardian;
      if (current == null) return;
      await _save(guardian: current.copyWith(offsets: update(current.offsets)));
    }
  }

  Future<void> _save({
    InstructorReminders? instructor,
    GuardianReminders? guardian,
  }) async {
    final previous = state.value!;
    state = AsyncData(
      previous.copyWith(instructor: instructor, guardian: guardian),
    );
    try {
      state = AsyncData(
        await _repository.save(instructor: instructor, guardian: guardian),
      );
      ref.invalidate(agendaProvider);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationSettingsController,
      NotificationSettings
    >(NotificationSettingsController.new, retry: (_, _) => null);
