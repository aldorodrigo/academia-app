import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';
import '../../organizations/presentation/roles_list.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(session?.name ?? ''),
            subtitle: Text(session?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(session?.organization?.name ?? ''),
            subtitle: const Text('Organización activa'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Tus perfiles', style: theme.textTheme.titleMedium),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: RolesList(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          if ((session?.organizations.length ?? 0) > 1)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Cambiar de organización'),
              onTap: () => context.go('/organizaciones'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
