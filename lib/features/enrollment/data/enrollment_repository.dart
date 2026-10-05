import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

/// Inscripciones desde la app: el tutor las pide (el chico entra ya y va a
/// clases), quien tiene `manage_enrollment_requests` las confirma o rechaza y
/// quien tiene `create_students` carga alumnos directo.
class EnrollmentRepository {
  EnrollmentRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Dónde se puede inscribir; con [birthDate], la categoría sugerida por edad.
  Future<List<EnrollmentOption>> options({DateTime? birthDate}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/enrollment-requests/options',
      queryParameters: {
        if (birthDate != null) 'birth_date': apiDate(birthDate),
      },
    );
    return (response.data!['data'] as List)
        .map((o) => EnrollmentOption.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<EnrollmentRequest> submit(EnrollmentRequestDraft draft) async {
    final document = draft.document?.trim() ?? '';
    final notes = draft.notes?.trim() ?? '';
    final response = await _dio.post<Map<String, dynamic>>(
      '/enrollment-requests',
      data: {
        'first_name': draft.firstName.trim(),
        'last_name': draft.lastName.trim(),
        'birth_date': apiDate(draft.birthDate),
        'document': document,
        'relationship': draft.relationship.value,
        'season_id': draft.seasonId,
        'group_id': draft.groupId,
        if (notes.isNotEmpty) 'notes': notes,
        if (!draft.medical.isEmpty) 'medical': draft.medical.toJson(),
      },
    );
    return EnrollmentRequest.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Las solicitudes propias: pendientes y las no aprobadas recientes.
  Future<List<EnrollmentRequest>> mine() async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/enrollment-requests',
    );
    return _list(response.data!);
  }

  /// Retira una solicitud propia que todavía está en revisión.
  Future<void> cancel(int id) => _dio.delete<void>('/enrollment-requests/$id');

  /// Para quien aprueba: las que esperan revisión, o las últimas con [all].
  Future<List<EnrollmentRequest>> review({bool all = false}) async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/enrollment-requests/review',
      queryParameters: {'status': all ? 'todos' : 'pendiente'},
    );
    return _list(response.data!);
  }

  /// Da de alta al chico. Lo que no se manda queda como lo pidió el tutor y
  /// según el plan de la temporada.
  Future<EnrollmentRequest> approve(
    int id, {
    int? groupId,
    String? midPeriod,
    bool overCapacity = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/enrollment-requests/$id/approve',
      data: {
        'group_id': ?groupId,
        'mid_period': ?midPeriod,
        if (overCapacity) 'over_capacity': true,
      },
    );
    return EnrollmentRequest.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<EnrollmentRequest> reject(int id, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/enrollment-requests/$id/reject',
      data: {'reason': reason.trim()},
    );
    return EnrollmentRequest.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// "Cargar alumno": alta directa con la invitación del tutor.
  Future<RegisteredStudent> registerStudent(
    StudentRegistrationDraft draft,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/students',
      data: {
        'first_name': draft.firstName.trim(),
        'last_name': draft.lastName.trim(),
        'birth_date': apiDate(draft.birthDate),
        'document': draft.document.trim(),
        'season_id': draft.seasonId,
        'group_id': draft.groupId,
        'guardian': draft.guardian.toJson(),
      },
    );
    return RegisteredStudent.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  List<EnrollmentRequest> _list(Map<String, dynamic> body) =>
      (body['data'] as List)
          .map((r) => EnrollmentRequest.fromJson(r as Map<String, dynamic>))
          .toList();
}

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) => EnrollmentRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Opciones de inscripción para una fecha de nacimiento.
final enrollmentOptionsProvider = FutureProvider.autoDispose
    .family<List<EnrollmentOption>, DateTime>(
      (ref, birthDate) =>
          ref.watch(enrollmentRepositoryProvider).options(birthDate: birthDate),
    );

/// Las solicitudes propias. Se vuelve a pedir al cambiar de organización.
final myEnrollmentRequestsProvider = FutureProvider<List<EnrollmentRequest>>((
  ref,
) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  return ref.watch(enrollmentRepositoryProvider).mine();
});

/// Para quien aprueba: `false` = en revisión, `true` = las últimas.
final enrollmentReviewProvider = FutureProvider.autoDispose
    .family<List<EnrollmentRequest>, bool>((ref, all) async {
      final slug = await ref.watch(
        sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
      );
      if (slug == null) return const [];
      return ref.watch(enrollmentRepositoryProvider).review(all: all);
    });
