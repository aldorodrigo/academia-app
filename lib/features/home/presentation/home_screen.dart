import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.organization?.name ?? 'Inicio'),
        actions: [
          if ((session?.organizations.length ?? 0) > 1)
            IconButton(
              tooltip: 'Cambiar de organización',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => context.go('/organizaciones'),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Hola, ${session?.name ?? ''}.\n\n'
            'Acá vas a ver a tus hijos, sus cuotas y los avisos del club.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
