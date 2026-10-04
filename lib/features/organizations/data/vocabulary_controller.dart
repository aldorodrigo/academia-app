import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'organization_repository.dart';

/// Palabras que se cambian desde la app, en el orden de la pantalla.
const vocabularyKeys = ['student', 'instructor', 'group', 'space'];

/// Guarda cómo les dicen y vuelve a pedir la organización (y con ella la
/// guía, que usa esas palabras en sus títulos).
class VocabularyActions {
  VocabularyActions(this._ref);

  final Ref _ref;

  /// [terminology] vacío = "Dejar como estaba" (solo lo confirma). Devuelve el
  /// error o null.
  Future<String?> save(Map<String, String> terminology) async {
    try {
      await _ref
          .read(organizationRepositoryProvider)
          .updateTerminology(terminology);
    } catch (error) {
      return apiErrorMessage(error);
    }
    _ref.invalidate(currentOrganizationProvider);
    return null;
  }
}

final vocabularyActionsProvider = Provider<VocabularyActions>(
  VocabularyActions.new,
);

/// "Cómo les dicen" (`/vocabulario`): las palabras mientras se eligen.
class VocabularyController extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    final organization = await ref.read(currentOrganizationProvider.future);
    return {
      for (final key in vocabularyKeys) key: organization?.term(key) ?? key,
    };
  }

  void set(String key, String value) {
    final draft = state.value;
    final word = value.trim();
    if (draft == null || word.isEmpty) return;
    state = AsyncData({...draft, key: word});
  }

  Future<String?> save() async {
    final draft = state.value;
    if (draft == null) return null;
    return ref.read(vocabularyActionsProvider).save(draft);
  }
}

final vocabularyProvider =
    AsyncNotifierProvider.autoDispose<
      VocabularyController,
      Map<String, String>
    >(VocabularyController.new, retry: (_, _) => null);
