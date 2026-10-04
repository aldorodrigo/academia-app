import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos guardados en el celular para trabajar sin conexión (caché y envíos
/// pendientes). Texto por clave; se reemplaza en los tests.
abstract class OfflineStore {
  Future<String?> read(String key);

  /// Null borra la clave.
  Future<void> write(String key, String? value);

  /// Borra todo (al cerrar sesión).
  Future<void> clear();
}

class SharedPreferencesOfflineStore implements OfflineStore {
  static const _prefix = 'offline:';

  // Se crea al usarlo: así no falla donde no hay plugin (tests que no lo usan).
  late final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString('$_prefix$key');

  @override
  Future<void> write(String key, String? value) => value == null
      ? _preferences.remove('$_prefix$key')
      : _preferences.setString('$_prefix$key', value);

  @override
  Future<void> clear() async {
    final keys = await _preferences.getKeys();
    await _preferences.clear(
      allowList: keys.where((k) => k.startsWith(_prefix)).toSet(),
    );
  }
}

final offlineStoreProvider = Provider<OfflineStore>(
  (ref) => SharedPreferencesOfflineStore(),
);

/// True mientras el dispositivo tiene alguna conexión.
final connectivityProvider = StreamProvider<bool>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  ),
);
