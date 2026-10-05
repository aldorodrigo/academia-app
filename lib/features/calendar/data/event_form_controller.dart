import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import 'calendar_providers.dart';
import 'calendar_repository.dart';
import 'models.dart';

/// Días máximos de un evento o día sin clase (como la API).
const maxEventDays = 92;

/// Errores por campo (con las claves de la API) antes de enviar.
Map<String, String> validateEventDraft(EventDraft draft, DateTime today) {
  final errors = <String, String>{};
  if (draft.category == null) errors['category'] = 'Elegí el tipo.';
  final title = draft.title.trim();
  if (title.isEmpty) {
    errors['title'] = 'Escribí un título.';
  } else if (title.length > 120) {
    errors['title'] = 'Hasta 120 caracteres.';
  }
  final start = draft.startsOn;
  final end = draft.endsOn;
  if (start == null) {
    errors['starts_on'] = 'Elegí la fecha.';
  } else {
    if (draft.isDayOff && start.isBefore(today)) {
      errors['starts_on'] = 'Un día sin clase no puede empezar antes de hoy.';
    }
    if (end != null && end.isBefore(start)) {
      errors['ends_on'] = 'La fecha de fin no puede ser anterior al inicio.';
    } else if (end != null && end.difference(start).inDays + 1 > maxEventDays) {
      errors['ends_on'] = 'Elegí hasta $maxEventDays días.';
    }
  }
  if (!draft.isDayOff && !draft.allDay) {
    final from = minutesOf(draft.startsAt ?? '');
    final to = minutesOf(draft.endsAt ?? '');
    if (from == null) {
      errors['starts_at'] = 'Elegí la hora.';
    } else if (to == null) {
      errors['ends_at'] = 'Elegí la hora de fin.';
    } else if (to <= from) {
      errors['ends_at'] = 'La hora de fin tiene que ser posterior al inicio.';
    }
  }
  if (!draft.forEveryone && draft.groupIds.isEmpty) {
    errors['group_ids'] = 'Elegí para quién es.';
  }
  return errors;
}

/// Con qué arranca el formulario: un tipo y un día, o un evento para editar.
typedef EventFormArgs = ({
  EventKind kind,
  DateTime? date,
  CalendarEvent? event,
});

class EventFormState {
  const EventFormState({
    required this.draft,
    this.errors = const {},
    this.preview,
    this.previewLoading = false,
    this.previewError,
    this.notify = true,
    this.submitting = false,
    this.error,
  });

  final EventDraft draft;

  /// Errores por campo (claves de la API: `title`, `starts_on`, `group_ids`…).
  final Map<String, String> errors;

  /// Null hasta que haya fecha y destinatarios para calcularla. Mientras se
  /// recalcula ([previewLoading]) queda la anterior.
  final EventPreview? preview;
  final bool previewLoading;
  final String? previewError;

  /// Al editar: "Avisar del cambio".
  final bool notify;
  final bool submitting;
  final String? error;

  EventFormState copyWith({
    EventDraft? draft,
    Map<String, String>? errors,
    EventPreview? Function()? preview,
    bool? previewLoading,
    String? Function()? previewError,
    bool? notify,
    bool? submitting,
    String? Function()? error,
  }) => EventFormState(
    draft: draft ?? this.draft,
    errors: errors ?? this.errors,
    preview: preview == null ? this.preview : preview(),
    previewLoading: previewLoading ?? this.previewLoading,
    previewError: previewError == null ? this.previewError : previewError(),
    notify: notify ?? this.notify,
    submitting: submitting ?? this.submitting,
    error: error == null ? this.error : error(),
  );
}

/// Formulario para publicar o editar un evento o un día sin clase, con la
/// vista previa de a quién le llega y qué clases se suspenden.
class EventFormController extends Notifier<EventFormState> {
  EventFormController(this.args);

  final EventFormArgs args;

  Timer? _debounce;
  int _previewRequest = 0;

  bool get isEditing => args.event != null;

  @override
  EventFormState build() {
    ref.onDispose(() => _debounce?.cancel());
    final event = args.event;
    final draft = event != null
        ? EventDraft.fromEvent(event)
        : EventDraft(kind: args.kind, startsOn: args.date);
    if (event != null && _previewable(draft)) {
      _debounce = Timer(Duration.zero, _loadPreview);
    }
    return EventFormState(draft: draft);
  }

  /// Cambia el borrador; borra los errores de lo que se tocó y recalcula la vista previa.
  void update(EventDraft Function(EventDraft draft) change) {
    final draft = change(state.draft);
    final errors = {
      for (final entry in state.errors.entries)
        if (_sameField(entry.key, state.draft, draft)) entry.key: entry.value,
    };
    state = state.copyWith(draft: draft, errors: errors, error: () => null);
    _schedulePreview(draft);
  }

  /// Elige la categoría; en un día sin clase, sugiere el título si está vacío.
  void selectCategory(EventCategoryOption option) => update(
    (d) => d.copyWith(
      category: option.value,
      title: d.isDayOff && d.title.trim().isEmpty ? option.label : null,
    ),
  );

  /// Con un solo grupo para elegir (técnico con una categoría), ya queda elegido.
  void applyOptions(EventOptions options) {
    final draft = state.draft;
    if (isEditing || draft.groupIds.isNotEmpty || draft.forEveryone) return;
    if (options.canTargetOrganization || options.groups.length != 1) return;
    update((d) => d.copyWith(groupIds: {options.groups.single.id}));
  }

  void setNotify(bool value) => state = state.copyWith(notify: value);

  /// Marca los errores del formulario; true si se puede enviar.
  bool validate() {
    final errors = validateEventDraft(state.draft, ref.read(todayProvider));
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Publica o guarda; null si hay errores (quedan en el estado).
  Future<CalendarEvent?> submit() async {
    if (state.submitting || !validate()) return null;
    state = state.copyWith(submitting: true, error: () => null);
    final actions = ref.read(calendarActionsProvider);
    final event = args.event;
    try {
      final saved = event == null
          ? await actions.publish(state.draft)
          : await actions.update(event.id, state.draft, notify: state.notify);
      if (ref.mounted) state = state.copyWith(submitting: false);
      return saved;
    } catch (error) {
      if (!ref.mounted) return null;
      final fields = _fieldErrors(error);
      state = state.copyWith(
        submitting: false,
        errors: fields,
        error: () => fields.isEmpty ? apiErrorMessage(error) : null,
      );
      return null;
    }
  }

  static bool _previewable(EventDraft draft) =>
      draft.startsOn != null &&
      (draft.forEveryone || draft.groupIds.isNotEmpty);

  void _schedulePreview(EventDraft draft) {
    _debounce?.cancel();
    if (!_previewable(draft)) {
      _previewRequest++;
      state = state.copyWith(
        preview: () => null,
        previewLoading: false,
        previewError: () => null,
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _loadPreview);
  }

  Future<void> _loadPreview() async {
    final request = ++_previewRequest;
    state = state.copyWith(previewLoading: true, previewError: () => null);
    try {
      final preview = await ref
          .read(calendarRepositoryProvider)
          .preview(state.draft, eventId: args.event?.id);
      if (!ref.mounted || request != _previewRequest) return;
      state = state.copyWith(preview: () => preview, previewLoading: false);
    } catch (error) {
      if (!ref.mounted || request != _previewRequest) return;
      state = state.copyWith(
        previewLoading: false,
        previewError: () => apiErrorMessage(error),
      );
    }
  }

  /// El campo de la API no cambió entre los dos borradores.
  static bool _sameField(String field, EventDraft a, EventDraft b) =>
      switch (field) {
        'category' => a.category == b.category,
        'title' => a.title == b.title,
        'starts_on' ||
        'ends_on' => a.startsOn == b.startsOn && a.endsOn == b.endsOn,
        'starts_at' || 'ends_at' =>
          a.allDay == b.allDay &&
              a.startsAt == b.startsAt &&
              a.endsAt == b.endsAt,
        'group_ids' || 'for_everyone' =>
          a.forEveryone == b.forEveryone && a.groupIds == b.groupIds,
        'place' || 'venue_id' => a.place == b.place && a.venueId == b.venueId,
        'description' => a.description == b.description,
        _ => true,
      };
}

/// Errores 422 de la API por campo (el primero de cada uno).
Map<String, String> _fieldErrors(Object error) {
  if (error is! DioException || error.response?.statusCode != 422) {
    return const {};
  }
  final data = error.response?.data;
  if (data is! Map || data['errors'] is! Map) return const {};
  return {
    for (final entry in (data['errors'] as Map).entries)
      if (entry.value is List && (entry.value as List).isNotEmpty)
        _field(entry.key.toString()): (entry.value as List).first.toString(),
  };
}

/// `group_ids.0` → `group_ids`.
String _field(String key) => key.split('.').first;

final eventFormProvider = NotifierProvider.autoDispose
    .family<EventFormController, EventFormState, EventFormArgs>(
      EventFormController.new,
    );
