import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_service.dart';
import '../../../core/storage/offline_store.dart';
import '../../attendance/data/attendance_outbox.dart';
import '../../invitations/data/invitation_repository.dart';
import 'auth_repository.dart';
import 'models.dart';

/// Estado de la sesión: null = no autenticado.
class SessionController extends AsyncNotifier<Session?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<Session?> build() => _repository.restore();

  Future<void> login({required String email, required String password}) async {
    await _repository.login(email: email, password: password);
    state = AsyncData(await _repository.restore());
  }

  /// Acepta una invitación y entra directo a la organización que invitó.
  Future<void> acceptInvitation(
    String token, {
    required String password,
    String? name,
    String? passwordConfirmation,
  }) async {
    await ref
        .read(invitationRepositoryProvider)
        .accept(
          token,
          name: name,
          password: password,
          passwordConfirmation: passwordConfirmation,
        );
    state = AsyncData(await _repository.restore());
  }

  Future<void> selectOrganization(String slug) async {
    await _repository.selectOrganization(slug);
    final session = state.value;
    if (session != null) {
      state = AsyncData(session.copyWith(organizationSlug: slug));
    }
  }

  Future<void> logout() async {
    await ref.read(pushServiceProvider).unregister();
    await _repository.logout();
    // Lo guardado para trabajar sin conexión es de esta cuenta.
    try {
      await ref.read(offlineStoreProvider).clear();
    } catch (_) {}
    ref.invalidate(attendanceOutboxProvider);
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
