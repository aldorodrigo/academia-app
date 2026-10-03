import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/session_controller.dart';
import '../../organizations/data/organization_repository.dart';
import 'models.dart';
import 'onboarding_repository.dart';

/// Plantillas del alta y de la guía (no cambian durante la sesión).
final onboardingTemplatesProvider = FutureProvider<OnboardingTemplates>(
  (ref) => ref.watch(onboardingRepositoryProvider).templates(),
);

/// Guía de la organización activa; null si el usuario no la configura.
class OnboardingController extends AsyncNotifier<Onboarding?> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<Onboarding?> build() async {
    final organization = await ref.watch(currentOrganizationProvider.future);
    if (organization == null || !organization.can('configure_organization')) {
      return null;
    }
    return _repository.onboarding();
  }

  /// Vuelve a calcular los pasos (después de guardar uno).
  Future<Onboarding?> reload() async {
    final value = await AsyncValue.guard(_repository.onboarding);
    state = value;
    return value.value;
  }

  Future<String?> _run(Future<Onboarding> Function() action) async {
    try {
      state = AsyncData(await action());
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }

  Future<String?> dismiss() => _run(() => _repository.setDismissed(true));

  Future<String?> reopen() => _run(() => _repository.setDismissed(false));

  Future<String?> skip(String key) => _run(() => _repository.skip(key));
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, Onboarding?>(
      OnboardingController.new,
      retry: (_, _) => null,
    );

/// Organizaciones donde la guía ya se abrió sola en esta sesión de la app.
class SetupAutoOpened extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void mark(String slug) => state = {...state, slug};
}

final setupAutoOpenedProvider = NotifierProvider<SetupAutoOpened, Set<String>>(
  SetupAutoOpened.new,
);

/// La guía se abre sola si está incompleta, no se cerró y todavía no se
/// abrió en esta sesión.
bool shouldAutoOpen(Onboarding? onboarding, Set<String> opened, String? slug) =>
    onboarding != null &&
    slug != null &&
    !onboarding.completed &&
    !onboarding.dismissed &&
    !opened.contains(slug);

/// Adónde ir después de guardar un paso: "¡Listo!" si la guía estaba
/// incompleta al entrar al paso y ahora está completa; si no, el siguiente
/// pendiente (o la lista).
String nextRoute(Onboarding? after, {required bool wasCompleted}) {
  if (after == null) return '/inicio';
  if (after.completed) {
    return wasCompleted ? '/configurar' : '/configurar/listo';
  }
  return stepRoutes[after.next] ?? '/configurar';
}

// ---------------------------------------------------------------------------
// Tu club

/// Datos del club mientras se completan.
class ClubDraft {
  const ClubDraft({
    this.name = '',
    this.type = 'club',
    this.terminology = const {},
    this.customTerms = false,
    this.slug,
    this.slugTaken,
  });

  final String name;
  final String type;
  final Map<String, String> terminology;

  /// El usuario cambió el vocabulario: cambiar el tipo ya no lo pisa.
  final bool customTerms;

  /// Identificador libre (sugerido desde el nombre o elegido).
  final String? slug;

  /// El que pidió y no estaba libre (para explicarlo).
  final String? slugTaken;

  ClubDraft copyWith({
    String? name,
    String? type,
    Map<String, String>? terminology,
    bool? customTerms,
    String? slug,
    String? slugTaken,
    bool clearSlugTaken = false,
  }) => ClubDraft(
    name: name ?? this.name,
    type: type ?? this.type,
    terminology: terminology ?? this.terminology,
    customTerms: customTerms ?? this.customTerms,
    slug: slug ?? this.slug,
    slugTaken: clearSlugTaken ? null : (slugTaken ?? this.slugTaken),
  );

  String term(String key) => terminology[key] ?? _defaults[key] ?? key;

  static const _defaults = {
    'program': 'Disciplina',
    'group': 'Categoría',
    'student': 'Jugador',
    'instructor': 'Técnico',
    'guardian': 'Tutor',
  };

  /// "Jugadores, técnicos y categorías".
  String get termsSummary =>
      '${pluralize(term('student'))}, ${pluralize(term('instructor')).toLowerCase()} '
      'y ${pluralize(term('group')).toLowerCase()}';

  String? validate() {
    if (name.trim().length < 3) return 'Ingresá el nombre del club.';
    if (slug == null) return 'Esperá a que revisemos el nombre.';
    return null;
  }
}

class ClubFormController extends AsyncNotifier<ClubDraft> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<ClubDraft> build() async {
    final templates = await ref.watch(onboardingTemplatesProvider.future);
    final type = templates.organizationTypes.isEmpty
        ? 'club'
        : templates.organizationTypes.first.value;
    return ClubDraft(
      type: type,
      terminology: templates.type(type)?.terminology ?? const {},
    );
  }

  ClubDraft? get _draft => state.value;

  void setName(String name) {
    final draft = _draft;
    if (draft != null) state = AsyncData(draft.copyWith(name: name));
  }

  void setType(String type) {
    final draft = _draft;
    if (draft == null) return;
    final templates = ref.read(onboardingTemplatesProvider).value;
    state = AsyncData(
      draft.copyWith(
        type: type,
        terminology: draft.customTerms
            ? null
            : templates?.type(type)?.terminology ?? draft.terminology,
      ),
    );
  }

  void setTerm(String key, String value) {
    final draft = _draft;
    if (draft == null) return;
    state = AsyncData(
      draft.copyWith(
        terminology: {...draft.terminology, key: value},
        customTerms: true,
      ),
    );
  }

  /// Revisa el identificador (desde el nombre o el que escribió) y usa uno libre.
  Future<void> checkSlug(String value) async {
    if (value.trim().isEmpty) return;
    try {
      final check = await _repository.checkSlug(value.trim());
      final draft = _draft;
      if (draft == null) return;
      state = AsyncData(
        draft.copyWith(
          slug: check.usable,
          slugTaken: check.available ? null : check.slug,
          clearSlugTaken: check.available,
        ),
      );
    } catch (_) {
      // Sin respuesta, el botón espera a que se pueda revisar.
    }
  }

  /// Crea el club y entra a él; devuelve el error o null.
  Future<String?> create() async {
    final draft = _draft;
    if (draft == null) return null;
    final error = draft.validate();
    if (error != null) return error;
    try {
      final slug = await _repository.createOrganization(
        name: draft.name.trim(),
        type: draft.type,
        slug: draft.slug!,
        terminology: draft.terminology,
      );
      // La guía se abre ahora: no hace falta que se abra sola otra vez.
      ref.read(setupAutoOpenedProvider.notifier).mark(slug);
      await ref.read(sessionControllerProvider.notifier).reload(select: slug);
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final clubFormProvider =
    AsyncNotifierProvider.autoDispose<ClubFormController, ClubDraft>(
      ClubFormController.new,
      retry: (_, _) => null,
    );
