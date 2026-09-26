import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

class StudentsRepository {
  StudentsRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Alumnos a cargo del usuario (sus hijos, o él mismo si es alumno adulto).
  Future<List<Student>> list() async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>('/students');
    return (response.data!['data'] as List)
        .map((s) => Student.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Ficha completa: horarios, tutores y ficha médica si hay permiso.
  Future<Student> find(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/students/$id');
    return Student.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

final studentsRepositoryProvider = Provider<StudentsRepository>(
  (ref) => StudentsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Se vuelve a pedir cada vez que cambia la organización elegida.
final studentsProvider = FutureProvider<List<Student>>((ref) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  return ref.watch(studentsRepositoryProvider).list();
});

/// Sin reintentos: un 404 (alumno ajeno o inexistente) no se arregla reintentando.
final studentProvider = FutureProvider.autoDispose.family<Student, int>(
  (ref, id) => ref.watch(studentsRepositoryProvider).find(id),
  retry: (_, _) => null,
);
