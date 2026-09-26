import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/data/models.dart';
import 'features/auth/data/session_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/organizations/presentation/organization_picker_screen.dart';

/// Decide a dónde ir según el estado de la sesión.
String? sessionRedirect(AsyncValue<Session?> session, String location) {
  if (session.isLoading) return location == '/' ? null : '/';

  final value = session.value;
  if (value == null) return location == '/ingresar' ? null : '/ingresar';

  if (value.organizationSlug == null) {
    return location == '/organizaciones' ? null : '/organizaciones';
  }

  if (location == '/' || location == '/ingresar') return '/inicio';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => sessionRedirect(
      ref.read(sessionControllerProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/ingresar', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/organizaciones',
        builder: (_, _) => const OrganizationPickerScreen(),
      ),
      GoRoute(path: '/inicio', builder: (_, _) => const HomeScreen()),
    ],
  );
});
