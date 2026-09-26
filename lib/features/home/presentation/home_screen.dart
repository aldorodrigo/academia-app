import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';
import '../../organizations/presentation/roles_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.organization?.name ?? 'Inicio'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/cuenta'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Hola, ${session?.name ?? ''}.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const RolesList(),
          const SizedBox(height: 32),
          const Text(
            'Acá vas a ver a tus hijos, sus cuotas y los avisos del club.',
          ),
        ],
      ),
    );
  }
}
