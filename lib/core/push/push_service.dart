import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../config/env.dart';

/// Notificaciones push: registro del dispositivo en la API y rutas a abrir
/// cuando se toca una notificación. Se reemplaza en los tests.
abstract class PushService {
  /// Pide permiso (si hace falta) y registra el dispositivo. False si no hay
  /// push (web, sin configurar o permiso denegado).
  Future<bool> enable();

  /// Registra el dispositivo solo si ya hay permiso, sin preguntar.
  Future<void> registerIfAllowed();

  /// Borra el dispositivo de la API (al cerrar sesión).
  Future<void> unregister();

  /// Rutas de la app a abrir al tocar una notificación (`data.route`).
  Stream<String> get openedRoutes;
}

/// Sin push: web o sin proyecto de Firebase configurado.
class DisabledPushService implements PushService {
  const DisabledPushService();

  @override
  Future<bool> enable() async => false;

  @override
  Future<void> registerIfAllowed() async {}

  @override
  Future<void> unregister() async {}

  @override
  Stream<String> get openedRoutes => const Stream.empty();
}

class FirebasePushService implements PushService {
  FirebasePushService(this._dio);

  final Dio _dio;
  final _routes = StreamController<String>.broadcast();
  Future<FirebaseMessaging>? _messaging;
  String? _token;

  Future<FirebaseMessaging> _init() => _messaging ??= () async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial);
    messaging.onTokenRefresh.listen(_register);
    return messaging;
  }();

  void _open(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.startsWith('/')) _routes.add(route);
  }

  Future<void> _register(String token) async {
    _token = token;
    await _dio.post<void>(
      '/devices',
      data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
  }

  bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  Future<bool> _registerCurrent(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null) return false;
    await _register(token);
    return true;
  }

  @override
  Future<bool> enable() async {
    try {
      final messaging = await _init();
      final settings = await messaging.requestPermission();
      if (!_allowed(settings)) return false;
      return await _registerCurrent(messaging);
    } catch (error) {
      debugPrint('Push no disponible: $error');
      return false;
    }
  }

  @override
  Future<void> registerIfAllowed() async {
    try {
      final messaging = await _init();
      if (_allowed(await messaging.getNotificationSettings())) {
        await _registerCurrent(messaging);
      }
    } catch (error) {
      debugPrint('Push no disponible: $error');
    }
  }

  @override
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await _dio.delete<void>('/devices/${Uri.encodeComponent(token)}');
    } on DioException {
      // Si falla, la API lo borra cuando FCM avise que el token ya no sirve.
    }
    _token = null;
  }

  @override
  Stream<String> get openedRoutes => _routes.stream;
}

final pushServiceProvider = Provider<PushService>((ref) {
  if (kIsWeb || !Env.hasFirebase) return const DisabledPushService();
  return FirebasePushService(ref.watch(apiClientProvider));
});

/// Ruta a abrir por una notificación tocada.
final pushOpenedRouteProvider = StreamProvider<String>(
  (ref) => ref.watch(pushServiceProvider).openedRoutes,
);
