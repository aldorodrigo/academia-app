import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_service.dart';
import 'core/storage/offline_store.dart';
import 'features/attendance/data/attendance_outbox.dart';
import 'features/auth/data/session_controller.dart';
import 'router.dart';

/// La app es solo en español. flutter_localizations se usa únicamente para
/// que los widgets de Flutter (calendarios, diálogos) muestren sus textos en
/// español; no hay traducciones propias.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  static const locale = Locale('es');

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  // Al volver a la app se envía la asistencia guardada sin conexión.
  late final _lifecycle = AppLifecycleListener(onResume: _flushOutbox);

  void _flushOutbox() {
    if (ref.read(sessionControllerProvider).value?.organizationSlug == null) {
      return;
    }
    ref.read(attendanceOutboxProvider.notifier).flush().ignore();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Con sesión en una organización, registra el dispositivo para push si ya
    // hay permiso (el permiso se pide al activar un aviso) y envía lo pendiente.
    ref.listen(
      sessionControllerProvider.select((s) => s.value?.organizationSlug),
      (_, slug) {
        if (slug == null) return;
        ref.read(pushServiceProvider).registerIfAllowed();
        _flushOutbox();
      },
    );
    // Al volver la señal, también.
    ref.listen(connectivityProvider, (previous, next) {
      if (next.value == true && previous?.value != true) _flushOutbox();
    });
    // Tocar una notificación abre su pantalla.
    ref.listen(pushOpenedRouteProvider, (_, route) {
      final path = route.value;
      if (path != null) router.go(path);
    });

    return MaterialApp.router(
      title: 'Academia',
      debugShowCheckedModeBanner: false,
      locale: App.locale,
      supportedLocales: const [App.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF059669)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      routerConfig: router,
    );
  }
}
