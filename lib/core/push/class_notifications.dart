import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/env.dart';

/// Push de clases que la app dibuja con botones (llegan solo con `data` en
/// Android): "¿Lo llevás?" con [Sí, va] [No va] y el aviso del técnico con
/// [Tomar asistencia].
class ActionablePush {
  const ActionablePush({
    required this.type,
    required this.title,
    required this.body,
    required this.route,
    this.classId,
    this.goingUrl,
    this.notGoingUrl,
  });

  static const reminder = 'class_reminder';
  static const today = 'class_today';

  /// Null si el push no es de los que llevan botones.
  static ActionablePush? fromData(Map<String, dynamic> data) {
    final type = data['type'];
    if (type != reminder && type != today) return null;
    return ActionablePush(
      type: type as String,
      title: data['title'] as String? ?? 'Día de clase',
      body: data['body'] as String? ?? '',
      route: data['route'] as String? ?? '/inicio',
      classId: int.tryParse('${data['class_id']}'),
      goingUrl: data['going_url'] as String?,
      notGoingUrl: data['not_going_url'] as String?,
    );
  }

  final String type;
  final String title;
  final String body;
  final String route;
  final int? classId;
  final String? goingUrl;
  final String? notGoingUrl;

  bool get canRespond => goingUrl != null && notGoingUrl != null;

  /// Una notificación por clase (la respuesta la reemplaza).
  int get notificationId => (classId ?? body.hashCode) & 0x7fffffff;

  /// Lo que viaja en la notificación para saber qué hacer al tocarla.
  String get payload => jsonEncode({
    'route': route,
    'going_url': goingUrl,
    'not_going_url': notGoingUrl,
  });
}

/// Qué hacer con un toque en la notificación.
sealed class NotificationTap {
  const NotificationTap();

  static NotificationTap? from(String? actionId, String? payload) {
    final data = payload == null
        ? const <String, dynamic>{}
        : jsonDecode(payload) as Map<String, dynamic>;
    final url = switch (actionId) {
      ClassNotifications.goingAction => data['going_url'],
      ClassNotifications.notGoingAction => data['not_going_url'],
      _ => null,
    };
    if (url is String) return RespondTap(url);
    final route = data['route'];
    return route is String && route.startsWith('/') ? OpenTap(route) : null;
  }
}

/// Responder "¿Lo llevás?" sin abrir la app.
class RespondTap extends NotificationTap {
  const RespondTap(this.url);

  final String url;
}

/// Abrir una pantalla de la app.
class OpenTap extends NotificationTap {
  const OpenTap(this.route);

  final String route;
}

/// Envía la respuesta por el link firmado del push (no necesita la sesión) y
/// devuelve el texto para mostrar en la notificación.
Future<String> respondFromNotification(Dio dio, String url) async {
  try {
    final response = await dio.postUri<Map<String, dynamic>>(Uri.parse(url));
    final data = response.data?['data'] as Map<String, dynamic>?;
    return data?['message'] as String? ?? 'Listo.';
  } on DioException catch (error) {
    final body = error.response?.data;
    if (error.response?.statusCode == 403) {
      return 'Este aviso venció. Abrí la app para responder.';
    }
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return 'No se pudo enviar. Abrí la app para responder.';
  }
}

/// Notificaciones locales con botones (Android e iOS).
class ClassNotifications {
  ClassNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const goingAction = 'going';
  static const notGoingAction = 'not_going';
  static const openAction = 'open';
  static const _reminderCategory = 'CLASS_REMINDER';
  static const _todayCategory = 'CLASS_TODAY';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize({ValueChanged<String>? onOpen}) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _reminderCategory,
              actions: [
                DarwinNotificationAction.plain(goingAction, 'Sí, va'),
                DarwinNotificationAction.plain(notGoingAction, 'No va'),
              ],
            ),
            DarwinNotificationCategory(
              _todayCategory,
              actions: [
                DarwinNotificationAction.plain(
                  openAction,
                  'Tomar asistencia',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          handle(response, onOpen: onOpen),
      onDidReceiveBackgroundNotificationResponse:
          notificationActionInBackground,
    );
  }

  /// Ruta de la notificación con la que se abrió la app (si fue así).
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || response == null) {
      return null;
    }
    final tap = NotificationTap.from(response.actionId, response.payload);
    return tap is OpenTap ? tap.route : null;
  }

  Future<void> show(ActionablePush push) => _plugin.show(
    id: push.notificationId,
    title: push.title,
    body: push.body,
    payload: push.payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        push.type == ActionablePush.today ? 'mis_clases' : 'dias_de_clase',
        push.type == ActionablePush.today ? 'Mis clases' : 'Días de clase',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(push.body),
        actions: push.type == ActionablePush.today
            ? const [
                AndroidNotificationAction(
                  openAction,
                  'Tomar asistencia',
                  showsUserInterface: true,
                ),
              ]
            : push.canRespond
            ? const [
                AndroidNotificationAction(goingAction, 'Sí, va'),
                AndroidNotificationAction(notGoingAction, 'No va'),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: push.type == ActionablePush.today
            ? _todayCategory
            : _reminderCategory,
      ),
    ),
  );

  /// Botón o toque: responde por el link firmado o abre la pantalla.
  Future<void> handle(
    NotificationResponse response, {
    ValueChanged<String>? onOpen,
    Dio? dio,
  }) async {
    final tap = NotificationTap.from(response.actionId, response.payload);
    switch (tap) {
      case RespondTap(:final url):
        final message = await respondFromNotification(dio ?? _dio(), url);
        await _plugin.show(
          id: response.id ?? 0,
          title: 'Día de clase',
          body: message,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'dias_de_clase',
              'Días de clase',
            ),
          ),
        );
      case OpenTap(:final route):
        onOpen?.call(route);
      case null:
        break;
    }
  }

  static Dio _dio() => Dio(
    BaseOptions(
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
}

/// Botón tocado con la app cerrada (Android): corre en otro isolate.
@pragma('vm:entry-point')
Future<void> notificationActionInBackground(
  NotificationResponse response,
) async {
  final notifications = ClassNotifications();
  await notifications.initialize();
  await notifications.handle(response);
}

/// Push que llega con la app cerrada o en segundo plano: dibuja los que llevan botones.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  final push = ActionablePush.fromData(message.data);
  if (push == null) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: Env.firebaseOptions);
  }
  final notifications = ClassNotifications();
  await notifications.initialize();
  await notifications.show(push);
}
