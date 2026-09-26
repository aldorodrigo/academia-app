/// Configuración por entorno, vía `--dart-define`.
///
/// Ejemplo: flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api/v1
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost/api/v1',
  );
}
