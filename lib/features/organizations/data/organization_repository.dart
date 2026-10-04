import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

class OrganizationRepository {
  OrganizationRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Organización activa o null si todavía no se eligió una.
  Future<OrganizationDetails?> current() async {
    if (await _storage.readOrganization() == null) return null;

    final response = await _dio.get<Map<String, dynamic>>('/organization');
    return OrganizationDetails.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Cambia cómo les dicen (`PUT organization/terminology`); vacío = solo
  /// confirma lo que hay ("Dejar como estaba"). Devuelve el vocabulario entero.
  Future<Map<String, String>> updateTerminology(
    Map<String, String> terminology,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/organization/terminology',
      data: {'terminology': terminology},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return Map<String, String>.from(data['terminology'] as Map? ?? const {});
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Se vuelve a pedir cada vez que cambia la organización elegida.
final currentOrganizationProvider = FutureProvider<OrganizationDetails?>((
  ref,
) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return null;
  return ref.watch(organizationRepositoryProvider).current();
});
