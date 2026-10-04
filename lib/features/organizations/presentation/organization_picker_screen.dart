import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';

class OrganizationPickerScreen extends ConsumerWidget {
  const OrganizationPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final organizations = session?.organizations ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegí una organización'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: organizations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Tu usuario todavía no pertenece a ninguna organización.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.go('/registro/club'),
                        child: const Text('Registrar mi club'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/invitacion'),
                        child: const Text('Tengo una invitación'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.separated(
              itemCount: organizations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final organization = organizations[index];
                return ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(organization.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref
                      .read(sessionControllerProvider.notifier)
                      .selectOrganization(organization.slug),
                );
              },
            ),
    );
  }
}
