import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

/// Bajas y condonación (`academia-api/docs/PLAN_BAJAS.md`): avisos de baja, dar de baja,
/// condonar y deshacer (con permiso), y el aviso del tutor "deja el club".
class WithdrawalsRepository {
  WithdrawalsRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Map<String, dynamic> _data(Map<String, dynamic>? body) =>
      body!['data'] as Map<String, dynamic>;

  /// Avisos de baja sin decidir (técnico o tutor), para quien puede dar de baja.
  Future<List<DropoutReport>> dropoutReports() async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>('/dropout-reports');
    return (response.data!['data'] as List)
        .map((r) => DropoutReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ManagedStudent> student(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/staff/students/$id',
    );
    return ManagedStudent.fromJson(_data(response.data));
  }

  /// Da de baja; devuelve a cuántos tutores se les avisó.
  Future<int> withdraw(int enrollmentId, WithdrawalDraft draft) async {
    final message = draft.message?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/enrollments/$enrollmentId/withdraw',
      data: {
        'ended_on': apiDate(draft.endedOn),
        'reason': draft.reason.trim(),
        'notify': draft.notify,
        if (draft.notify && message != null && message.isNotEmpty)
          'message': message,
      },
    );
    return _data(response.data)['notified'] as int? ?? 0;
  }

  /// "Sigue viniendo": descarta el aviso de baja.
  Future<void> dismissDropout(int enrollmentId) =>
      _dio.delete<void>('/enrollments/$enrollmentId/dropout');

  /// Condona lo pendiente; devuelve el total condonado.
  Future<int> waive(List<int> chargeIds, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/charges/waive',
      data: {'charge_ids': chargeIds, 'reason': reason.trim()},
    );
    return _data(response.data)['waived'] as int? ?? 0;
  }

  /// Deshace una condonación: la cuota vuelve a quedar pendiente.
  Future<void> unwaive(int chargeId, String reason) => _dio.post<void>(
    '/charges/$chargeId/unwaive',
    data: {'reason': reason.trim()},
  );

  /// El tutor avisa que su hijo deja el club (mensaje opcional). Devuelve la fecha.
  Future<DateTime> reportLeaving(int studentId, {String? message}) async {
    final text = message?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/students/$studentId/leaving',
      data: {if (text != null && text.isNotEmpty) 'message': text},
    );
    return DateTime.parse(
      _data(response.data)['leaving_reported_on'] as String,
    );
  }

  /// El tutor deshace su aviso.
  Future<void> cancelLeaving(int studentId) =>
      _dio.delete<void>('/students/$studentId/leaving');
}

final withdrawalsRepositoryProvider = Provider<WithdrawalsRepository>(
  (ref) => WithdrawalsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Se vuelve a pedir cada vez que cambia la organización elegida.
final dropoutReportsProvider = FutureProvider.autoDispose<List<DropoutReport>>((
  ref,
) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  return ref.watch(withdrawalsRepositoryProvider).dropoutReports();
});

final managedStudentProvider = FutureProvider.autoDispose
    .family<ManagedStudent, int>(
      (ref, id) => ref.watch(withdrawalsRepositoryProvider).student(id),
      retry: (_, _) => null,
    );
