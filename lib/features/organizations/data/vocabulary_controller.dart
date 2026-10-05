import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'organization_repository.dart';

/// Palabras que se cambian desde la app, en el orden de la pantalla.
const vocabularyKeys = ['student', 'instructor', 'group', 'space'];

/// Las de persona: se puede ajustar cómo se nombra a una mujer ("Si es mujer").
const personVocabularyKeys = ['student', 'instructor'];

/// En el borrador, la forma femenina de [key] va en `feminine.<key>`.
String feminineKey(String key) => 'feminine.$key';

/// Guarda cómo les dicen y vuelve a pedir la organización (y con ella la
/// guía, que usa esas palabras en sus títulos).
class VocabularyActions {
  VocabularyActions(this._ref);

  final Ref _ref;

  /// [terminology] vacío = "Dejar como estaba" (solo lo confirma). Devuelve el
  /// error o null.
  Future<String?> save(
    Map<String, String> terminology, {
    Map<String, String>? feminine,
  }) async {
    try {
      await _ref
          .read(organizationRepositoryProvider)
          .updateTerminology(terminology, feminine: feminine);
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
      for (final key in personVocabularyKeys)
        feminineKey(key): ?organization?.terminologyFeminine[key],
    };
  }

  void set(String key, String value) {
    final draft = state.value;
    final word = value.trim();
    if (draft == null || word.isEmpty) return;
    state = AsyncData({...draft, key: word});
  }

  /// "Si es mujer": vacía = la de la regla (Jugador → Jugadora).
  void setFeminine(String key, String value) {
    final draft = state.value;
    if (draft == null) return;
    state = AsyncData({...draft, feminineKey(key): value.trim()});
  }

  Future<String?> save() async {
    final draft = state.value;
    if (draft == null) return null;
    return ref.read(vocabularyActionsProvider).save(
      {for (final key in vocabularyKeys) key: draft[key]!},
      // Solo las que se tocaron (o ya estaban ajustadas); sin ninguna, no se mandan.
      feminine:
          personVocabularyKeys.any((key) => draft.containsKey(feminineKey(key)))
          ? {
              for (final key in personVocabularyKeys)
                key: draft[feminineKey(key)] ?? '',
            }
          : null,
    );
  }
}

final vocabularyProvider =
    AsyncNotifierProvider.autoDispose<
      VocabularyController,
      Map<String, String>
    >(VocabularyController.new, retry: (_, _) => null);
