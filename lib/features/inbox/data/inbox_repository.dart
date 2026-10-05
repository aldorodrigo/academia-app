import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../auth/data/session_controller.dart';

/// Un aviso de la bandeja: la copia de cada push o correo que le llegó a la
/// cuenta en la organización activa (`GET me/notifications`).
class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type,
    this.route,
    this.readAt,
  });

  factory InboxNotification.fromJson(Map<String, dynamic> json) =>
      InboxNotification(
        id: json['id'] as String,
        type: json['type'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        route: json['route'] as String?,
        readAt: _wallClock(json['read_at']),
        createdAt: _wallClock(json['created_at'])!,
      );

  final String id;
  final String? type;
  final String title;
  final String body;

  /// Pantalla de la app a la que lleva (ej. `/inicio`), si tiene.
  final String? route;

  /// Hora de la organización (la que viene en el texto, sin pasar a UTC).
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  InboxNotification markedRead(DateTime at) => InboxNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    route: route,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );
}

DateTime? _wallClock(Object? value) => value is String && value.length >= 19
    ? DateTime.parse(value.substring(0, 19))
    : null;

/// Una página de la bandeja, con cuántos quedan sin leer.
class InboxPage {
  const InboxPage({
    required this.items,
    required this.unread,
    this.currentPage = 1,
    this.lastPage = 1,
  });

  factory InboxPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return InboxPage(
      items: ((json['data'] as List?) ?? const [])
          .map((n) => InboxNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unread: meta['unread'] as int? ?? 0,
      currentPage: meta['current_page'] as int? ?? 1,
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  static const empty = InboxPage(items: [], unread: 0);

  final List<InboxNotification> items;
  final int unread;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

class InboxRepository {
  InboxRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<InboxPage> page([int page = 1]) async {
    if (await _storage.readOrganization() == null) return InboxPage.empty;
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/notifications',
      queryParameters: {if (page > 1) 'page': page},
    );
    return InboxPage.fromJson(response.data!);
  }

  Future<void> markRead(String id) =>
      _dio.post<Object?>('/me/notifications/$id/read');

  Future<void> markAllRead() =>
      _dio.post<Object?>('/me/notifications/read-all');
}

final inboxRepositoryProvider = Provider<InboxRepository>(
  (ref) => InboxRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// La bandeja "Avisos": se van sumando páginas con "Ver más"; tocar un aviso lo
/// marca leído.
class InboxController extends AsyncNotifier<InboxPage> {
  InboxRepository get _repository => ref.read(inboxRepositoryProvider);

  @override
  Future<InboxPage> build() async {
    final slug = await ref.watch(
      sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
    );
    if (slug == null) return InboxPage.empty;
    return ref.watch(inboxRepositoryProvider).page();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final next = await _repository.page(current.currentPage + 1);
    state = AsyncData(
      InboxPage(
        items: [...current.items, ...next.items],
        unread: next.unread,
        currentPage: next.currentPage,
        lastPage: next.lastPage,
      ),
    );
  }

  /// Lo marca leído enseguida en pantalla y avisa a la API (sin bloquear).
  Future<void> markRead(InboxNotification notification) async {
    final current = state.value;
    if (current == null || notification.isRead) return;
    state = AsyncData(
      InboxPage(
        items: [
          for (final n in current.items)
            n.id == notification.id ? n.markedRead(DateTime.now()) : n,
        ],
        unread: current.unread > 0 ? current.unread - 1 : 0,
        currentPage: current.currentPage,
        lastPage: current.lastPage,
      ),
    );
    try {
      await _repository.markRead(notification.id);
    } catch (_) {
      // Queda sin leer en la API: se corrige al volver a abrir.
    }
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    final current = state.value;
    if (current == null) return;
    final now = DateTime.now();
    state = AsyncData(
      InboxPage(
        items: [for (final n in current.items) n.markedRead(now)],
        unread: 0,
        currentPage: current.currentPage,
        lastPage: current.lastPage,
      ),
    );
  }
}

final inboxProvider = AsyncNotifierProvider<InboxController, InboxPage>(
  InboxController.new,
  retry: (_, _) => null,
);

/// Avisos sin leer (0 si todavía no cargó o sin red).
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).value?.unread ?? 0,
);
