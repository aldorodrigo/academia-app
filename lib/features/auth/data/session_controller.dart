import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> selectOrganization(String slug) async {
    await _repository.selectOrganization(slug);
    final session = state.value;
    if (session != null) {
      state = AsyncData(session.copyWith(organizationSlug: slug));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
