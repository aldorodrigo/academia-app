import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import 'models.dart';

class InvitationRepository {
  InvitationRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<Invitation> fetch(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/invitations/$token',
    );
    return Invitation.fromJson(
      token,
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Acepta la invitación (crea la cuenta si hace falta) y deja la sesión
  /// iniciada en la organización que invitó.
  Future<void> accept(
    String token, {
    required String password,
    String? name,
    String? passwordConfirmation,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/invitations/$token/accept',
      data: {
        'name': ?name,
        'password': password,
        'password_confirmation': ?passwordConfirmation,
        'device_name': 'app',
      },
    );
    await _storage.writeToken(response.data!['token'] as String);
    await _storage.writeOrganization(response.data!['organization'] as String);
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Sin reintentos: una invitación inválida no se arregla reintentando.
final invitationProvider = FutureProvider.autoDispose
    .family<Invitation, String>(
      (ref, token) => ref.watch(invitationRepositoryProvider).fetch(token),
      retry: (_, _) => null,
    );
