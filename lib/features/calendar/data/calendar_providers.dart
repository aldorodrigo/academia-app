import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/session_controller.dart';
import 'calendar_repository.dart';
import 'models.dart';

/// Rango pedido a `GET calendar`, con el filtro de hijo o grupo.
typedef CalendarQuery = ({
  DateTime from,
  DateTime to,
  int? studentId,
  int? groupId,
});

/// Calendario de un rango; se vuelve a pedir al cambiar de organización.
final calendarProvider = FutureProvider.autoDispose
    .family<CalendarRange, CalendarQuery>((ref, query) async {
      await ref.watch(
        sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
      );
      return ref
          .watch(calendarRepositoryProvider)
          .calendar(
            query.from,
            query.to,
            studentId: query.studentId,
            groupId: query.groupId,
          );
    }, retry: (_, _) => null);

/// Próximos eventos y días sin clase (30 días, hasta 3) para el inicio.
final upcomingEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((
  ref,
) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  final today = ref.watch(todayProvider);
  final range = await ref
      .watch(calendarRepositoryProvider)
      .calendar(
        today,
        DateTime(today.year, today.month, today.day + 30),
        types: const {CalendarType.events},
      );
  final events = [
    for (final event in range.events)
      if (!event.cancelled && !event.endsOn.isBefore(today)) event,
  ]..sort((a, b) => a.startsOn.compareTo(b.startsOn));
  return events.take(3).toList();
}, retry: (_, _) => null);

final eventProvider = FutureProvider.autoDispose.family<CalendarEvent, int>(
  (ref, id) => ref.watch(calendarRepositoryProvider).event(id),
  retry: (_, _) => null,
);

final eventOptionsProvider = FutureProvider.autoDispose<EventOptions>(
  (ref) => ref.watch(calendarRepositoryProvider).options(),
  retry: (_, _) => null,
);

/// Link para sincronizar con Google Calendar o el Calendario de Apple.
final calendarFeedProvider = FutureProvider.autoDispose<CalendarFeed>(
  (ref) => ref.watch(calendarRepositoryProvider).feed(),
  retry: (_, _) => null,
);

/// Publicar, editar y cancelar eventos; refresca todo lo que los muestra.
class CalendarActions {
  CalendarActions(this._ref);

  final Ref _ref;

  CalendarRepository get _repository => _ref.read(calendarRepositoryProvider);

  Future<CalendarEvent> publish(EventDraft draft) async {
    final event = await _repository.publish(draft);
    _refresh(event);
    return event;
  }

  Future<CalendarEvent> update(
    int id,
    EventDraft draft, {
    bool notify = true,
  }) async {
    final event = await _repository.update(id, draft, notify: notify);
    _refresh(event);
    return event;
  }

  Future<CalendarEvent> cancel(int id, {String? reason}) async {
    final event = await _repository.cancel(id, reason: reason);
    _refresh(event);
    return event;
  }

  /// Link nuevo para sincronizar (el anterior deja de funcionar).
  Future<CalendarFeed> resetFeed() async {
    final feed = await _repository.resetFeed();
    _ref.invalidate(calendarFeedProvider);
    return feed;
  }

  void _refresh(CalendarEvent event) {
    _ref.invalidate(calendarProvider);
    _ref.invalidate(upcomingEventsProvider);
    _ref.invalidate(eventProvider(event.id));
    if (event.isDayOff) {
      // Las clases de esos días cambiaron (suspendidas o reanudadas).
      _ref.invalidate(agendaProvider);
      _ref.invalidate(classesProvider);
      _ref.invalidate(classProvider);
    }
  }
}

final calendarActionsProvider = Provider<CalendarActions>(CalendarActions.new);
