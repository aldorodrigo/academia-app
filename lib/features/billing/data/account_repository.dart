import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

class AccountRepository {
  AccountRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Consolidado de la familia (todos los alumnos a cargo del usuario).
  Future<Account> consolidated() async {
    if (await _storage.readOrganization() == null) return Account.empty;

    final response = await _dio.get<Map<String, dynamic>>('/account');
    return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  /// Estado de cuenta de un solo hijo.
  Future<Account> forStudent(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/students/$id/account',
    );
    return Account.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Se vuelve a pedir cada vez que cambia la organización elegida.
final accountProvider = FutureProvider<Account>((ref) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return Account.empty;
  return ref.watch(accountRepositoryProvider).consolidated();
});

/// Sin reintentos: un 404 (alumno ajeno) no se arregla reintentando.
final studentAccountProvider = FutureProvider.autoDispose.family<Account, int>(
  (ref, id) => ref.watch(accountRepositoryProvider).forStudent(id),
  retry: (_, _) => null,
);
