import 'package:firebase_core/firebase_core.dart';

/// Configuración por entorno, vía `--dart-define`.
///
/// Ejemplo: flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api/v1
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost/api/v1',
  );

  // Cloudflare Turnstile (anti-bots) al pedir códigos. Sin clave no se usa.
  // La URL tiene que estar en los dominios del widget en Cloudflare.
  static const turnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');
  static const turnstileBaseUrl = String.fromEnvironment(
    'TURNSTILE_BASE_URL',
    defaultValue: 'http://localhost/',
  );

  // Proyecto de Firebase para push (Android/iOS). Sin estos valores la app
  // funciona igual, sin notificaciones.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static const firebaseOptions = FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseSenderId,
    projectId: firebaseProjectId,
  );

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
