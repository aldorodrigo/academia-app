import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import 'models.dart';

/// Calendario de actividades: clases, particulares, eventos y días sin clase.
class CalendarRepository {
  CalendarRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Lo que el usuario ve entre dos días (hasta 42).
  Future<CalendarRange> calendar(
    DateTime from,
    DateTime to, {
    int? studentId,
    int? groupId,
    Set<CalendarType>? types,
  }) async {
    if (await _storage.readOrganization() == null) {
      return CalendarRange(from: from, to: to);
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/calendar',
      queryParameters: {
        'from': apiDate(from),
        'to': apiDate(to),
        'student_id': ?studentId,
        'group_id': ?groupId,
        if (types != null) 'types': types.map((t) => t.value).join(','),
      },
    );
    return CalendarRange.fromJson(_data(response.data!));
  }

  Future<CalendarEvent> event(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$id');
    return CalendarEvent.fromJson(_data(response.data!));
  }

  Future<EventOptions> options() async {
    final response = await _dio.get<Map<String, dynamic>>('/events/options');
    return EventOptions.fromJson(_data(response.data!));
  }

  Future<EventPreview> preview(EventDraft draft, {int? eventId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/preview',
      data: {...draft.toJson(), 'event_id': ?eventId},
    );
    return EventPreview.fromJson(_data(response.data!));
  }

  Future<CalendarEvent> publish(EventDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events',
      data: draft.toJson(),
    );
    return CalendarEvent.fromJson(_data(response.data!));
  }

  Future<CalendarEvent> update(
    int id,
    EventDraft draft, {
    bool notify = true,
  }) async {
    final json = draft.toJson()..remove('kind');
    final response = await _dio.put<Map<String, dynamic>>(
      '/events/$id',
      data: {...json, 'notify': notify},
    );
    return CalendarEvent.fromJson(_data(response.data!));
  }

  Future<CalendarEvent> cancel(int id, {String? reason}) async {
    final text = reason?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/$id/cancel',
      data: {'reason': text == null || text.isEmpty ? null : text},
    );
    return CalendarEvent.fromJson(_data(response.data!));
  }

  /// Link de suscripción del usuario (se crea la primera vez).
  Future<CalendarFeed> feed() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/calendar-feed');
    return CalendarFeed.fromJson(_data(response.data!));
  }

  /// Anula el link anterior y devuelve uno nuevo.
  Future<CalendarFeed> resetFeed() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/calendar-feed/reset',
    );
    return CalendarFeed.fromJson(_data(response.data!));
  }

  static Map<String, dynamic> _data(Map<String, dynamic> body) =>
      body['data'] as Map<String, dynamic>;
}

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);
