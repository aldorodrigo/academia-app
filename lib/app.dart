import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_service.dart';
import 'features/auth/data/session_controller.dart';
import 'router.dart';

/// La app es solo en español. flutter_localizations se usa únicamente para
/// que los widgets de Flutter (calendarios, diálogos) muestren sus textos en
/// español; no hay traducciones propias.
class App extends ConsumerWidget {
  const App({super.key});

  static const locale = Locale('es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Con sesión en una organización, registra el dispositivo para push si ya
    // hay permiso (el permiso se pide al activar un aviso).
    ref.listen(
      sessionControllerProvider.select((s) => s.value?.organizationSlug),
      (_, slug) {
        if (slug != null) ref.read(pushServiceProvider).registerIfAllowed();
      },
    );
    // Tocar una notificación abre su pantalla.
    ref.listen(pushOpenedRouteProvider, (_, route) {
      final path = route.value;
      if (path != null) router.go(path);
    });

    return MaterialApp.router(
      title: 'Academia',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [locale],
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
